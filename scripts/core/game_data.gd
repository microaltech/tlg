extends RefCounted
## Data statis game: jabatan, penasihat, selir, dan rumus tahap kampanye.
## Ubah angka di sini untuk menyeimbangkan game tanpa menyentuh logika.

const ATTRS := ["str", "int", "pol", "cha"]
const ATTR_NAMES := {
	"str": "Kekuatan",
	"int": "Kecerdasan",
	"pol": "Politik",
	"cha": "Karisma",
}

## Jabatan sang Tuan. prestige = syarat naik ke jabatan ini.
const RANKS := [
	{"name": "Kepala Desa", "prestige": 0, "max_charges": 3, "mult": 1.0, "level_cap": 20, "child_seats": 2},
	{"name": "Camat", "prestige": 300, "max_charges": 4, "mult": 1.25, "level_cap": 40, "child_seats": 3},
	{"name": "Bupati", "prestige": 1500, "max_charges": 5, "mult": 1.5, "level_cap": 60, "child_seats": 4},
	{"name": "Gubernur", "prestige": 6000, "max_charges": 6, "mult": 2.0, "level_cap": 80, "child_seats": 5},
	{"name": "Menteri", "prestige": 16000, "max_charges": 7, "mult": 2.5, "level_cap": 100, "child_seats": 6},
	{"name": "Perdana Menteri", "prestige": 35000, "max_charges": 8, "mult": 3.0, "level_cap": 150, "child_seats": 8},
]

## Kelangkaan penasihat untuk gacha. rate = peluang per tarikan.
const RARITIES := {
	"r": {"name": "Langka", "rate": 0.75, "color": "4a90d9", "dup_silver": 1500},
	"sr": {"name": "Epik", "rate": 0.21, "color": "a05bd6", "dup_silver": 5000},
	"ssr": {"name": "Legenda", "rate": 0.04, "color": "f0a830", "dup_silver": 20000},
}

## Aturan rekrut (gacha).
const GACHA_COST := 100
const GACHA_COST_10 := 900
const GACHA_PITY := 50  ## Legenda dijamin paling lambat di tarikan ke-50.
const GACHA_FREE_SECONDS := 86400
## Banner rate-up: tiap minggu satu Legenda unggulan. Peluang Legenda yang didapat
## adalah unggulan; bila meleset, Legenda berikutnya pasti unggulan.
const RATEUP_CHANCE := 0.5
const START_GOLD := 300
const PROMOTE_GOLD := 150
const MAX_STARS := 5
const STAR_BONUS := 0.2  ## +20% atribut per bintang.

## Penasihat (hero). unlock_stage = tahap kampanye yang harus dimenangkan;
## -1 berarti hanya bisa didapat lewat rekrut (gacha).
const COUNSELORS := [
	{"id": "arya", "name": "Arya Wiraguna", "rarity": "r", "str": 9, "int": 6, "pol": 5, "cha": 4, "unlock_stage": 0},
	{"id": "sekar", "name": "Sekar Pandita", "rarity": "r", "str": 3, "int": 10, "pol": 7, "cha": 5, "unlock_stage": 0},
	{"id": "bayu", "name": "Bayu Lelana", "rarity": "r", "str": 5, "int": 5, "pol": 10, "cha": 6, "unlock_stage": 3},
	{"id": "ratna", "name": "Ratna Kencana", "rarity": "sr", "str": 4, "int": 7, "pol": 6, "cha": 11, "unlock_stage": 6},
	{"id": "gajah", "name": "Gajah Mandala", "rarity": "sr", "str": 14, "int": 5, "pol": 6, "cha": 5, "unlock_stage": 10},
	{"id": "dewi", "name": "Dewi Prameswari", "rarity": "sr", "str": 6, "int": 13, "pol": 9, "cha": 8, "unlock_stage": 15},
	{"id": "satria", "name": "Satria Mahesa", "rarity": "ssr", "str": 16, "int": 9, "pol": 8, "cha": 9, "unlock_stage": 22},
	{"id": "lintang", "name": "Lintang Sari", "rarity": "r", "str": 7, "int": 6, "pol": 5, "cha": 7, "unlock_stage": -1},
	{"id": "danu", "name": "Danu Wiradana", "rarity": "r", "str": 6, "int": 5, "pol": 8, "cha": 5, "unlock_stage": -1},
	{"id": "wening", "name": "Wening Kirana", "rarity": "sr", "str": 5, "int": 14, "pol": 10, "cha": 7, "unlock_stage": -1},
	{"id": "bagas", "name": "Bagas Pamungkas", "rarity": "sr", "str": 15, "int": 6, "pol": 5, "cha": 8, "unlock_stage": -1},
	{"id": "kedaton", "name": "Ratu Sekar Kedaton", "rarity": "ssr", "str": 8, "int": 15, "pol": 12, "cha": 18, "unlock_stage": -1},
	{"id": "resi", "name": "Resi Darma Wicaksana", "rarity": "ssr", "str": 7, "int": 19, "pol": 16, "cha": 10, "unlock_stage": -1},
	{"id": "rangga", "name": "Rangga Lawe", "rarity": "sr", "str": 16, "int": 5, "pol": 6, "cha": 9, "unlock_stage": 30},
	{"id": "sora", "name": "Lembu Sora", "rarity": "r", "str": 8, "int": 6, "pol": 11, "cha": 5, "unlock_stage": 40},
	{"id": "tantular", "name": "Mpu Tantular", "rarity": "ssr", "str": 5, "int": 20, "pol": 15, "cha": 11, "unlock_stage": 50},
	{"id": "kusuma", "name": "Kusuma Wardhani", "rarity": "sr", "str": 5, "int": 9, "pol": 15, "cha": 8, "unlock_stage": -1},
	{"id": "jaka", "name": "Jaka Tingkir", "rarity": "ssr", "str": 20, "int": 9, "pol": 7, "cha": 12, "unlock_stage": -1},
	{"id": "nawang", "name": "Nawang Wulan", "rarity": "ssr", "str": 6, "int": 12, "pol": 10, "cha": 20, "unlock_stage": -1},
]

## Skill pasif penasihat: nilai = base + per_star x bintang (dalam pecahan, 0.05 = 5%).
## Efek: yield_silver/yield_grain/yield_soldiers/yield_all (hasil urusan), battle (korban
## kampanye berkurang), combat (kekuatan tempur arena/bos/perang), visit (peluang anak),
## train_cost (biaya latih berkurang), prestige (prestise kampanye).
const SKILLS := {
	"arya": {"name": "Tombak Garuda", "effect": "battle", "base": 0.05, "per_star": 0.02},
	"sekar": {"name": "Kitab Pajak", "effect": "yield_silver", "base": 0.05, "per_star": 0.02},
	"bayu": {"name": "Irigasi Subur", "effect": "yield_grain", "base": 0.05, "per_star": 0.02},
	"ratna": {"name": "Pesona Ratna", "effect": "yield_soldiers", "base": 0.06, "per_star": 0.02},
	"gajah": {"name": "Benteng Baja", "effect": "battle", "base": 0.08, "per_star": 0.03},
	"dewi": {"name": "Diplomasi Dewi", "effect": "prestige", "base": 0.10, "per_star": 0.03},
	"satria": {"name": "Panji Satria", "effect": "combat", "base": 0.10, "per_star": 0.03},
	"lintang": {"name": "Panah Lintang", "effect": "combat", "base": 0.04, "per_star": 0.02},
	"danu": {"name": "Hemat Bendahara", "effect": "train_cost", "base": 0.08, "per_star": 0.02},
	"wening": {"name": "Strategi Wening", "effect": "yield_silver", "base": 0.08, "per_star": 0.03},
	"bagas": {"name": "Pukulan Bagas", "effect": "combat", "base": 0.06, "per_star": 0.02},
	"kedaton": {"name": "Titah Ratu", "effect": "visit", "base": 0.08, "per_star": 0.02},
	"resi": {"name": "Kebijaksanaan Resi", "effect": "yield_all", "base": 0.08, "per_star": 0.02},
	"rangga": {"name": "Amuk Ranggalawe", "effect": "combat", "base": 0.08, "per_star": 0.03},
	"sora": {"name": "Sawah Tuban", "effect": "yield_grain", "base": 0.06, "per_star": 0.02},
	"tantular": {"name": "Kakawin Sutasoma", "effect": "train_cost", "base": 0.12, "per_star": 0.03},
	"kusuma": {"name": "Lumbung Kusuma", "effect": "yield_grain", "base": 0.08, "per_star": 0.03},
	"jaka": {"name": "Banteng Tingkir", "effect": "battle", "base": 0.10, "per_star": 0.03},
	"nawang": {"name": "Selendang Bidadari", "effect": "visit", "base": 0.10, "per_star": 0.03},
}
## Pusaka (peralatan): satu per slot per penasihat. Bonus atribut datar yang naik
## EQUIP_LEVEL_BONUS per level. Didapat dari tahap besar kampanye, perang, dan menara.
const EQUIP_SLOTS := {
	"weapon": {"name": "Senjata", "icon": "eq_weapon"},
	"book": {"name": "Kitab", "icon": "eq_book"},
	"charm": {"name": "Perhiasan", "icon": "eq_charm"},
}
const EQUIPMENT := {
	"keris_besi": {"name": "Keris Besi", "slot": "weapon", "rarity": "r", "attrs": {"str": 30}},
	"tombak_klinting": {"name": "Tombak Baru Klinting", "slot": "weapon", "rarity": "sr", "attrs": {"str": 80}},
	"keris_nagasasra": {"name": "Keris Nagasasra", "slot": "weapon", "rarity": "ssr", "attrs": {"str": 180}},
	"lontar_kuno": {"name": "Lontar Kuno", "slot": "book", "rarity": "r", "attrs": {"int": 30}},
	"kitab_negara": {"name": "Kitab Negarakertagama", "slot": "book", "rarity": "sr", "attrs": {"int": 60, "pol": 40}},
	"lontar_kalimasada": {"name": "Lontar Kalimasada", "slot": "book", "rarity": "ssr", "attrs": {"int": 120, "pol": 80}},
	"cincin_perak": {"name": "Cincin Perak", "slot": "charm", "rarity": "r", "attrs": {"cha": 30}},
	"kalung_kencana": {"name": "Kalung Kencana", "slot": "charm", "rarity": "sr", "attrs": {"cha": 80}},
	"mahkota_binokasih": {"name": "Mahkota Binokasih", "slot": "charm", "rarity": "ssr", "attrs": {"cha": 150, "pol": 50}},
}
const EQUIP_MAX_LEVEL := 10
const EQUIP_LEVEL_BONUS := 0.2  ## +20% bonus dasar per level di atas 1
## Biaya tingkatkan = dasar * level^1.6 perak; lebur mengembalikan nilai dasar + 30% biaya.
const EQUIP_UPGRADE_BASE := {"r": 2000, "sr": 5000, "ssr": 12000}
const EQUIP_SALVAGE_BASE := {"r": 500, "sr": 1500, "ssr": 5000}
const EQUIP_SALVAGE_REFUND := 0.3
const EQUIP_CAPACITY := 60
## Peluang pusaka jatuh di tahap besar (tiap tahap ke-5) dan bobot kelangkaannya.
const EQUIP_DROP_CHANCE := 0.5


static func equip_def(id: String) -> Dictionary:
	return EQUIPMENT.get(id, {})


## Pilih pusaka acak: makin tinggi tahap, makin besar peluang Epik/Legenda.
static func equip_roll(stage: int, roll: float, pick: float) -> String:
	var ssr := clampf(0.03 + stage * 0.002, 0.03, 0.2)
	var sr := clampf(0.22 + stage * 0.004, 0.22, 0.45)
	var rarity := "ssr" if roll < ssr else ("sr" if roll < ssr + sr else "r")
	var pool := EQUIPMENT.keys().filter(func(k): return EQUIPMENT[k]["rarity"] == rarity)
	return pool[mini(int(pick * pool.size()), pool.size() - 1)]


## Ikatan: aktif bila semua anggota dimiliki.
const BONDS := [
	{"name": "Pendekar Nusantara", "members": ["arya", "gajah", "satria"], "effect": "combat", "value": 0.10},
	{"name": "Cendekia Istana", "members": ["sekar", "dewi", "resi"], "effect": "yield_silver", "value": 0.10},
	{"name": "Penjaga Lumbung", "members": ["bayu", "danu"], "effect": "yield_grain", "value": 0.10},
	{"name": "Bunga Keraton", "members": ["ratna", "wening", "kedaton"], "effect": "prestige", "value": 0.15},
	{"name": "Busur dan Tinju", "members": ["lintang", "bagas"], "effect": "combat", "value": 0.05},
	{"name": "Laskar Majapahit", "members": ["gajah", "rangga", "sora"], "effect": "combat", "value": 0.10},
	{"name": "Putri Kahyangan", "members": ["dewi", "kedaton", "nawang"], "effect": "visit", "value": 0.10},
	{"name": "Para Pujangga", "members": ["resi", "tantular", "kusuma"], "effect": "yield_all", "value": 0.05},
]
const SKILL_CAP := 0.6
const SKILL_EFFECT_NAMES := {
	"yield_silver": "Hasil Tarik Pajak +%d%%", "yield_grain": "Hasil Kelola Sawah +%d%%",
	"yield_soldiers": "Hasil Rekrut Prajurit +%d%%", "yield_all": "Semua hasil urusan kota +%d%%",
	"battle": "Korban kampanye -%d%%", "combat": "Kekuatan tempur (arena/bos/perang) +%d%%",
	"visit": "Peluang anak lahir +%d%%", "train_cost": "Biaya latih penasihat -%d%%",
	"prestige": "Prestise dari kampanye +%d%%",
}

const BEAUTIES := [
	{"id": "melati", "name": "Melati", "unlock_stage": 0},
	{"id": "kenanga", "name": "Kenanga", "unlock_stage": 5},
	{"id": "anggrek", "name": "Anggrek", "unlock_stage": 12},
	{"id": "cempaka", "name": "Cempaka", "unlock_stage": 20},
	{"id": "kemuning", "name": "Kemuning", "unlock_stage": 28},
	{"id": "kantil", "name": "Kantil", "unlock_stage": 38},
]

const CHILD_NAMES := {
	"m": ["Adi", "Bima", "Dimas", "Fajar", "Indra", "Jaya", "Rangga", "Tirta", "Wira", "Yoga"],
	"f": ["Citra", "Gita", "Hana", "Kirana", "Laksmi", "Mega", "Putri", "Sari", "Utami", "Wulan"],
}

## Jenderal musuh bergiliran di tiap tahap kampanye (id = nama file potret).
const ENEMIES := [
	{"id": "enemy_bandit", "name": "Kepala Begal"},
	{"id": "enemy_rebel", "name": "Pemimpin Pemberontak"},
	{"id": "enemy_pirate", "name": "Bajak Laut Selat"},
	{"id": "enemy_warlord", "name": "Panglima Lalim"},
]

const CHILD_MAX_LEVEL := 10
## Pangan per level saat mendidik anak: biaya ke level n = CHILD_TRAIN_GRAIN * n.
const CHILD_TRAIN_GRAIN := 200
## Jeda (detik) sebelum anak yang sama bisa dididik lagi.
const CHILD_TRAIN_SECONDS := 1800
## Pangan yang dimakan tiap prajurit baru (urusan Rekrut Prajurit).
const SOLDIER_GRAIN := 0.75

## Ujian anak: anak dewasa bisa menjadi pejabat (bonus permanen hasil urusan kota).
const EXAM_COST_PER_TALENT := 1000  ## Perak.
const EXAM_BASE_CHANCE := 0.3
const EXAM_CHANCE_PER_TALENT := 0.12
const OFFICIALS_MAX := 8
## Gelar menurut skor (bakat + keberuntungan 0-2): min = skor minimal, bonus = hasil urusan.
const OFFICIAL_TITLES := [
	{"name": "Juru Tulis", "min": 0, "bonus": 0.01},
	{"name": "Hakim", "min": 3, "bonus": 0.02},
	{"name": "Adipati", "min": 5, "bonus": 0.03},
	{"name": "Menteri Muda", "min": 7, "bonus": 0.05},
]

## Perjamuan: sekali sehari per jenis. guests = jumlah tamu (+ anggota aliansi bila ada).
const BANQUETS := {
	"simple": {"name": "Jamuan Sederhana", "cost": {"silver": 5000, "grain": 3000}, "guests": 6,
		"prestige": 30, "per_guest": 5, "items": 1, "alliance_exp": 0},
	"grand": {"name": "Pesta Agung", "cost": {"gold": 300}, "guests": 12, "prestige": 150, "per_guest": 10,
		"items": 3, "alliance_exp": 100},
}
const BANQUET_GIFT_ITEMS := ["pill_intimacy", "energy_tea", "scroll_train", "silver_box", "grain_box"]
## Undangan perjamuan dari tuan lain tiap hari: datang dengan hadiah perak untuk prestise.
const INVITES_PER_DAY := 2
const INVITE_GIFT_SILVER := 1000
const INVITE_PRESTIGE := 12

## Penjara: tahanan tertangkap dari kemenangan kampanye, diinterogasi sampai mengaku.
const PRISON_CAPACITY := 5
const PRISON_CAPTURE_CHANCE := 0.5
const PRISON_DAILY_LIMIT := 15
const PRISON_COST_GRAIN := 300
const PRISON_HIT_SILVER := 30
const PRISON_METHODS := {
	"interrogate": {"name": "Interogasi", "attr": "int", "factor": 0.5, "desc": "Kecerdasan"},
	"intimidate": {"name": "Gertak", "attr": "str", "factor": 0.5, "desc": "Kekuatan"},
}
const PRISON_RELEASE_PRESTIGE := 5
const PRISON_CONFESS_ITEMS := ["silver_box", "grain_box", "troop_writ", "scroll_train", "pill_intimacy"]

static func prisoner_stats(stage_index: int) -> Dictionary:
	return {
		"hp": int(200 * pow(1.12, stage_index)),
		"silver": 500 + 150 * stage_index,
		"prestige": 15 + 3 * stage_index,
	}

## Misi harian: tiap hari dipilih DAILY_COUNT misi acak dari kumpulan ini.
## event = aksi yang dihitung; requires = syarat agar misi boleh muncul.
## Hadiah memakai kunci gold/silver/grain/soldiers.
const DAILY_COUNT := 5
const DAILY_POINTS := 20  ## Poin aktivitas per misi yang diklaim.
const DAILY_MISSIONS := [
	{"id": "affair10", "text": "Kerjakan urusan kota 10 kali", "event": "affair", "target": 10, "gold": 10, "silver": 500},
	{"id": "tax5", "text": "Tarik pajak 5 kali", "event": "affair_silver", "target": 5, "gold": 10, "grain": 500},
	{"id": "farm5", "text": "Kelola sawah 5 kali", "event": "affair_grain", "target": 5, "gold": 10, "silver": 500},
	{"id": "troops5", "text": "Rekrut prajurit 5 kali", "event": "affair_soldiers", "target": 5, "gold": 10, "grain": 500},
	{"id": "upgrade5", "text": "Latih penasihat 5 kali", "event": "upgrade", "target": 5, "gold": 20, "silver": 800},
	{"id": "win3", "text": "Menangkan 3 tahap kampanye", "event": "win", "target": 3, "gold": 25, "soldiers": 1000},
	{"id": "visit3", "text": "Kunjungi selir 3 kali", "event": "visit", "target": 3, "gold": 15, "grain": 600},
	{"id": "train3", "text": "Didik anak 3 kali", "event": "train", "target": 3, "gold": 15, "silver": 600, "requires": "children"},
	{"id": "gacha1", "text": "Rekrut penasihat 1 kali", "event": "recruit", "target": 1, "gold": 20, "silver": 500},
	{"id": "silver3k", "text": "Kumpulkan 3000 perak dari pajak", "event": "earn_silver", "target": 3000, "gold": 20, "grain": 800},
	{"id": "donate1", "text": "Sumbang ke aliansi 1 kali", "event": "donate", "target": 1, "gold": 15, "silver": 500, "requires": "alliance"},
	{"id": "boss2", "text": "Serang bos aliansi 2 kali", "event": "boss", "target": 2, "gold": 20, "soldiers": 800, "requires": "alliance"},
	{"id": "war2", "text": "Serang benteng dalam perang aliansi 2 kali", "event": "war", "target": 2, "gold": 20, "silver": 800, "requires": "alliance"},
	{"id": "jail3", "text": "Interogasi tahanan 3 kali", "event": "interrogate", "target": 3, "gold": 15, "silver": 600, "requires": "prisoners"},
	{"id": "feast1", "text": "Adakan perjamuan 1 kali", "event": "banquet", "target": 1, "gold": 15, "grain": 800},
	{"id": "arena3", "text": "Bertarung di arena 3 kali", "event": "arena", "target": 3, "gold": 20, "silver": 800, "requires": "arena"},
]
## Peti aktivitas: terbuka saat poin harian mencapai batas.
const DAILY_CHESTS := [
	{"points": 40, "gold": 20, "silver": 1000},
	{"points": 80, "gold": 30, "grain": 1500},
	{"points": 100, "gold": 60, "soldiers": 2000, "items": {"scroll_train": 1}},
]
## Hadiah login harian (7 hari berturut-turut). Terlewat sehari = kembali ke Hari 1.
const LOGIN_REWARDS := [
	{"gold": 50, "silver": 1000},
	{"grain": 2000, "soldiers": 1000},
	{"gold": 80, "items": {"energy_tea": 1}},
	{"silver": 3000, "grain": 2000},
	{"gold": 100, "soldiers": 2000},
	{"silver": 5000, "grain": 3000, "items": {"pill_intimacy": 2}},
	{"gold": 300, "soldiers": 5000, "items": {"recruit_ticket": 1}},
]
## Event mingguan: bergiliran tiap minggu (Senin 00:00 waktu setempat).
## points = poin event per aksi (nama aksi sama dengan event misi harian);
## bonus = efek khusus selama event berlangsung.
const EVENTS := [
	{"id": "harvest", "name": "Festival Panen", "icon": "event_harvest", "bg": "city",
		"desc": "Lumbung rakyat penuh! Kelola sawah dan didik anak untuk mengumpulkan poin.",
		"points": {"affair_grain": 10, "train": 30}, "bonus": {"yield_grain": 0.5},
		"bonus_text": "Hasil Kelola Sawah +50%"},
	{"id": "tournament", "name": "Turnamen Ksatria", "icon": "event_tournament", "bg": "campaign",
		"desc": "Para ksatria berlomba di medan laga. Menangkan kampanye dan latih penasihat.",
		"points": {"win": 60, "upgrade": 15, "boss": 20, "arena_win": 40, "war": 25}, "bonus": {"losses": -0.2},
		"bonus_text": "Prajurit gugur di kampanye -20%"},
	{"id": "market", "name": "Pasar Malam", "icon": "event_market", "bg": "city",
		"desc": "Pedagang dari seluruh negeri datang. Tarik pajak dan rekrut prajurit.",
		"points": {"affair_silver": 10, "affair_soldiers": 10}, "bonus": {"yield_silver": 0.5},
		"bonus_text": "Hasil Tarik Pajak +50%"},
	{"id": "palace", "name": "Pesta Istana", "icon": "event_palace", "bg": "palace",
		"desc": "Istana berhias bunga. Kunjungi selir, didik dan nikahkan anak.",
		"points": {"visit": 25, "train": 20, "marry": 150}, "bonus": {"child_chance": 0.15},
		"bonus_text": "Peluang anak lahir +15%"},
	{"id": "ritual", "name": "Ritual Purnama", "icon": "event_ritual", "bg": "gacha",
		"desc": "Bulan purnama memanggil para legenda. Rekrut penasihat dan urus kota.",
		"points": {"recruit": 60, "affair": 5, "upgrade": 10}, "bonus": {"ssr_rate": 0.03},
		"bonus_text": "Peluang Legenda di Rekrut 4% menjadi 7%"},
]
## Nama aksi untuk penjelasan cara mendapat poin event.
const EVENT_ACTION_NAMES := {
	"affair": "Urusan kota apa saja", "affair_silver": "Tarik pajak", "affair_grain": "Kelola sawah",
	"affair_soldiers": "Rekrut prajurit", "upgrade": "Latih penasihat", "win": "Menang kampanye",
	"visit": "Kunjungi selir", "train": "Didik anak", "marry": "Nikahkan anak",
	"recruit": "Rekrut penasihat (per tarikan)", "boss": "Serang bos aliansi", "donate": "Sumbang ke aliansi",
	"arena_win": "Menang di arena", "war": "Serang benteng dalam perang aliansi",
}
const EVENT_MISSION_POINTS := 50  ## Poin event untuk tiap misi harian yang diklaim.
const EVENT_TIERS := [
	{"points": 100, "gold": 30, "silver": 1000},
	{"points": 300, "grain": 3000, "soldiers": 2000},
	{"points": 600, "gold": 80},
	{"points": 1000, "silver": 8000, "grain": 5000},
	{"points": 1500, "gold": 150, "soldiers": 5000, "items": {"recruit_ticket": 1}},
	{"points": 2200, "silver": 15000, "grain": 10000},
	{"points": 3000, "gold": 400, "items": {"star_stone": 1}},
]
## Aliansi (anggota disimulasikan secara offline; lihat bagian Aliansi di game_model.gd).
const ALLIANCE_UNLOCK_STAGE := 5
const ALLIANCE_LEAVE_COOLDOWN := 86400
const ALLIANCES := [
	{"id": "garuda", "name": "Garuda Nusantara", "emblem": "emblem_garuda", "motto": "Terbang tinggi bersama!",
		"exp": 1800, "members": 18, "power": 1.0},
	{"id": "teratai", "name": "Teratai Emas", "emblem": "emblem_teratai", "motto": "Damai, makmur, sejahtera.",
		"exp": 700, "members": 12, "power": 0.7},
	{"id": "macan", "name": "Macan Kumbang", "emblem": "emblem_macan", "motto": "Kuat di medan laga.",
		"exp": 3800, "members": 24, "power": 1.4},
]
## Exp kumulatif untuk mencapai level 1..10.
const ALLIANCE_LEVELS := [0, 500, 1500, 3500, 7000, 12000, 20000, 32000, 50000, 80000]
const ALLIANCE_YIELD_PER_LEVEL := 0.03  ## Bonus hasil urusan kota per level aliansi.
const ALLIANCE_DONATIONS_PER_DAY := 3
const ALLIANCE_DONATIONS := [
	{"id": "silver", "label": "Sumbang Perak", "icon": "silver", "cost": {"silver": 5000}, "exp": 50, "jasa": 50},
	{"id": "grain", "label": "Sumbang Pangan", "icon": "grain", "cost": {"grain": 5000}, "exp": 50, "jasa": 50},
	{"id": "gold", "label": "Sumbang Emas", "icon": "gold", "cost": {"gold": 50}, "exp": 150, "jasa": 150},
]
## Toko aliansi: harga dalam Jasa, limit pembelian per hari, level aliansi minimal.
const ALLIANCE_SHOP := [
	{"id": "gold30", "name": "Kantong Emas", "icon": "gold", "reward": {"gold": 30}, "cost": 100, "limit": 1, "level": 1},
	{"id": "silver10k", "name": "Peti Perak", "icon": "silver", "reward": {"silver": 10000}, "cost": 80, "limit": 3, "level": 1},
	{"id": "grain10k", "name": "Lumbung Pangan", "icon": "grain", "reward": {"grain": 10000}, "cost": 80, "limit": 3, "level": 2},
	{"id": "soldiers5k", "name": "Pasukan Bantuan", "icon": "soldiers", "reward": {"soldiers": 5000}, "cost": 120, "limit": 2, "level": 3},
	{"id": "gold100", "name": "Peti Emas Besar", "icon": "chest", "reward": {"gold": 100}, "cost": 300, "limit": 1, "level": 5},
	{"id": "al_scroll", "name": "Gulungan Latihan", "icon": "item_scroll", "reward": {"items": {"scroll_train": 1}}, "cost": 150, "limit": 2, "level": 2},
	{"id": "al_star", "name": "Batu Bintang", "icon": "item_star", "reward": {"items": {"star_stone": 1}}, "cost": 600, "limit": 1, "level": 6},
]
const BOSS_NAME := "Buto Ijo"
const BOSS_ATTACKS_PER_DAY := 3
const BOSS_DAMAGE_PER_POWER := 25  ## Kerusakan pemain per serangan = kekuatan x ini (±10%).
const BOSS_NPC_DAMAGE_PER_POWER := 8  ## Kerusakan harian tiap anggota NPC.
const BOSS_HP_DAYS := 5.5  ## Tanpa bantuan pemain, NPC mengalahkan bos dalam ~5,5 hari.
const BOSS_ATTACK_JASA := 20
const BOSS_REWARD := {"gold": 100, "jasa": 200}
## Perang aliansi (mingguan, Senin-Minggu). Benteng diserang berurutan oleh NPC;
## Keraton Inti baru bisa diserang setelah WAR_CORE_UNLOCK benteng lain direbut.
const WAR_FORTS := [
	{"name": "Gerbang Utara", "hp": 1.0, "points": 100},
	{"name": "Menara Timur", "hp": 1.5, "points": 100},
	{"name": "Benteng Barat", "hp": 2.0, "points": 100},
	{"name": "Lumbung Selatan", "hp": 2.5, "points": 100},
	{"name": "Keraton Inti", "hp": 3.0, "points": 300},
]
const WAR_CORE_UNLOCK := 3
const WAR_HP_PER_POWER := 5  ## HP satuan benteng = total kekuatan NPC penyerang x ini.
const WAR_NPC_DAMAGE_PER_POWER := 6  ## Kerusakan harian NPC = total kekuatan x ini (±30%).
const WAR_ATTACKS_PER_DAY := 3
const WAR_DAMAGE_PER_POWER := 30
const WAR_CAPTURE_MERIT := 50
const WAR_REWARD_WIN := {"gold": 300, "jasa": 500}
const WAR_REWARD_LOSE := {"gold": 100, "jasa": 150}
const WAR_MERIT_PER_GOLD := 20  ## Bonus emas = jasa perang / ini (maks. WAR_MERIT_GOLD_MAX).
const WAR_MERIT_GOLD_MAX := 200

## Chat aliansi. Anggota NPC mengobrol tiap CHAT_SLOT_SECONDS (peluang CHAT_SLOT_CHANCE)
## dan membalas pesan pemain setelah beberapa detik. Placeholder: {player} {boss} {hp}
## {enemy} {ours} {theirs} {event} {alliance}.
const CHAT_MAX_MESSAGES := 60
const CHAT_MAX_LENGTH := 120
const CHAT_COOLDOWN := 2.0
const CHAT_SLOT_SECONDS := 1800
const CHAT_SLOT_CHANCE := 0.7
const CHAT_CATCHUP_SLOTS := 12
const CHAT_QUICK := ["Halo semua!", "Ayo serang bos!", "Terima kasih!", "Siap, gas perang!"]
const CHAT_BANNED := ["anjing", "bangsat", "babi", "kontol", "memek", "goblok", "tolol", "bajingan", "kampret", "asu",
	"fuck", "shit", "bitch", "bastard", "asshole"]
const CHAT_AMBIENT := {
	"greet": ["Selamat pagi semuanya!", "Halo, para Tuan!", "Ada yang sedang main?", "Semangat hari ini, kawan!"],
	"boss": ["{boss} tinggal {hp}% lagi, ayo serang!", "Sudah serang {boss} hari ini?", "Jangan lupa serangan bos ya!"],
	"boss_dead": ["{boss} sudah tumbang! Jangan lupa ambil hadiahnya.", "Hebat, {boss} kalah minggu ini!"],
	"war_ahead": ["Kita unggul {ours}-{theirs} melawan {enemy}! Pertahankan!", "{enemy} mulai kewalahan, terus tekan!"],
	"war_behind": ["Kita tertinggal {ours}-{theirs}, ayo serang benteng {enemy}!", "Butuh bantuan di perang melawan {enemy}!"],
	"donate": ["Jangan lupa sumbangan harian, aliansi butuh exp.", "Sudah sumbang hari ini? Jasanya bisa ditukar di toko."],
	"tips": ["Tips: latih penasihat berkekuatan tinggi untuk kampanye.", "Event minggu ini {event}, jangan sampai lewat!",
		"Rekrut gratis tiap hari, jangan lupa ya.", "Misi harian itu sumber emas paling gampang."],
	"chatter": ["Ada yang dapat Legenda dari rekrut?", "Arena hari ini ramai sekali.", "Siapa yang sudah liga Emas?",
		"Panen tahun ini melimpah!", "Istirahat dulu, nanti lanjut lagi."],
}
## Balasan untuk pesan pemain: kata kunci (huruf kecil) -> kategori.
## Kata kunci (Indonesia & Inggris, dicocokkan sebagai potongan teks) -> kategori balasan NPC.
const CHAT_KEYWORDS := {
	"greet": ["halo", "hai", "pagi", "siang", "sore", "malam", "hello", "salam", "hey", "morning", "evening",
		"greetings"],
	"thanks": ["terima kasih", "makasih", "thanks", "trims", "thank you", "thx"],
	"boss": ["bos", "boss", "buto"],
	"war": ["perang", "benteng", "keraton", "gas", "fort", "attack"],
	"help": ["bantu", "tolong", "gimana", "bagaimana", "cara", "help", "how do", "how to"],
}
const CHAT_REPLIES := {
	"greet": ["Halo juga, {player}!", "Hai {player}, selamat datang!", "Salam, {player}!"],
	"thanks": ["Sama-sama!", "Siap, kapan saja!", "Kita kan satu aliansi."],
	"boss": ["Ayo, saya baru saja serang {boss}!", "{boss} tinggal {hp}%, sedikit lagi!"],
	"war": ["Saya fokus ke benteng berikutnya!", "Skor kita {ours} lawan {theirs}, ayo!"],
	"help": ["Coba latih penasihat dan rekrut prajurit dulu.", "Lihat menu Panduan di Kota, lengkap di sana.",
		"Kerjakan misi harian, emasnya lumayan."],
	"default": ["Siap!", "Setuju!", "Mantap, {player}!", "Hahaha, betul juga.", "Oke, lanjutkan!"],
	"donate": ["Terima kasih atas sumbangannya, {player}!", "Mantap sumbangannya!"],
	"boss_hit": ["Serangan yang hebat!", "Bagus, {boss} makin lemah!"],
	"capture": ["Benteng direbut! Luar biasa!", "Hidup {alliance}!"],
}

const NPC_TITLES := ["Ki", "Nyi", "Raden", "Gusti", "Mpu", "Dyah", "Arya", "Rara"]
const NPC_NAMES := ["Rangga", "Sekar", "Bima", "Laras", "Wisnu", "Ayu", "Damar", "Kinanti", "Joko", "Sari",
	"Panji", "Wulan", "Seta", "Rukmini", "Tejo", "Asih", "Bayu", "Ratih", "Guntur", "Lestari", "Jati", "Puspa",
	"Galih", "Ningsih"]

## Arena PvP (lawan disimulasikan secara offline; lihat bagian Arena di game_model.gd).
const ARENA_UNLOCK_STAGE := 8
const ARENA_START_RATING := 1000
const ARENA_TICKETS := 5
const ARENA_TICKET_COST := 30  ## Emas per tiket tambahan.
const ARENA_TICKET_BUY_MAX := 5
const ARENA_REFRESH_FREE := 5
const ARENA_ELO_K := 32
const ARENA_WIN := {"coins": 20, "silver": 1500}
const ARENA_LOSS := {"coins": 5}
## Liga berdasarkan poin arena; reward = hadiah akhir musim (mingguan).
const ARENA_LEAGUES := [
	{"name": "Perunggu", "min": 0, "color": "b07a45", "stars": 1, "reward": {"gold": 50}},
	{"name": "Perak", "min": 1200, "color": "9aa4b0", "stars": 2, "reward": {"gold": 100, "silver": 5000}},
	{"name": "Emas", "min": 1500, "color": "e0a830", "stars": 3, "reward": {"gold": 200, "silver": 10000}},
	{"name": "Berlian", "min": 1800, "color": "4fb3d9", "stars": 4, "reward": {"gold": 350, "soldiers": 10000}},
	{"name": "Legenda", "min": 2200, "color": "c0392b", "stars": 5, "reward": {"gold": 600, "soldiers": 20000}},
]
const ARENA_SHOP := [
	{"id": "a_gold", "name": "Kantong Emas", "icon": "gold", "reward": {"gold": 40}, "cost": 100, "limit": 1},
	{"id": "a_silver", "name": "Peti Perak", "icon": "silver", "reward": {"silver": 15000}, "cost": 60, "limit": 3},
	{"id": "a_grain", "name": "Lumbung Pangan", "icon": "grain", "reward": {"grain": 15000}, "cost": 60, "limit": 3},
	{"id": "a_soldiers", "name": "Pasukan Bayaran", "icon": "soldiers", "reward": {"soldiers": 8000}, "cost": 80, "limit": 3},
	{"id": "a_ticket", "name": "Tiket Rekrut", "icon": "ticket_recruit", "reward": {"items": {"recruit_ticket": 1}}, "cost": 250, "limit": 1},
	{"id": "a_tea", "name": "Teh Semangat", "icon": "item_tea", "reward": {"items": {"energy_tea": 1}}, "cost": 120, "limit": 2},
]
## Potret yang dipakai sebagai avatar lawan arena.
const ARENA_AVATARS := ["arya", "sekar", "bayu", "ratna", "gajah", "lintang", "danu", "wening", "bagas",
	"enemy_bandit", "enemy_rebel", "enemy_pirate"]

## Tutorial pemain baru. target = elemen UI yang disorot (lihat main.gd tutorial_target);
## wait = "next" (tombol Lanjut), nama aksi (lihat _track di game_model.gd), atau "page:<halaman>".
const TUTORIAL_GUIDE := {"name": "Sekar Pandita", "portrait": "sekar"}
const TUTORIAL_STEPS := [
	{"text": "Selamat datang, Tuan! Saya Sekar Pandita, penasihat Anda. Mari saya tunjukkan cara memimpin kota ini.",
		"wait": "next"},
	{"text": "Ini sumber daya Anda: Perak, Pangan, Prajurit, dan Emas. Semuanya dibutuhkan untuk membangun kekuatan.",
		"target": "resources", "wait": "next"},
	{"text": "Tarik pajak dari rakyat untuk mendapat perak. Ketuk \"Kerjakan\" pada Tarik Pajak.",
		"target": "affair_silver", "wait": "affair_silver"},
	{"text": "Bagus! Sekarang rekrut prajurit untuk pasukan Anda.", "target": "affair_soldiers", "wait": "affair_soldiers"},
	{"text": "Urusan kota terisi lagi seiring waktu, bahkan saat game ditutup. Sekarang buka menu Penasihat.",
		"target": "nav_counselor", "wait": "page:counselor"},
	{"text": "Penasihat adalah kekuatan Anda. Latih penasihat dengan perak untuk menaikkan atributnya.",
		"target": "upgrade", "wait": "upgrade"},
	{"text": "Kekuatan penasihat menentukan hasil pertempuran. Ayo ke medan perang! Buka menu Kampanye.",
		"target": "nav_campaign", "wait": "page:campaign"},
	{"text": "Serang musuh untuk mendapat perak, prestise, dan emas. Ketuk \"SERANG!\".",
		"target": "attack", "wait": "battle"},
	{"text": "Emas bisa dipakai merekrut penasihat baru. Buka menu Rekrut.", "target": "nav_gacha", "wait": "page:gacha"},
	{"text": "Anda punya satu rekrut gratis setiap hari. Cobalah sekarang!", "target": "free_recruit", "wait": "recruit"},
	{"text": "Di Istana Anda bisa mengunjungi selir dan membesarkan anak. Buka menu Istana.",
		"target": "nav_palace", "wait": "page:palace"},
	{"text": "Kunjungi selir untuk menambah keakraban. Siapa tahu seorang anak akan lahir!",
		"target": "visit", "wait": "visit"},
	{"text": "Selesaikan misi harian dan ambil hadiah login setiap hari untuk mendapat Emas. Tombolnya ada di sini.",
		"target": "missions", "wait": "next"},
	{"text": "Hebat, Tuan! Anda siap memimpin. Terimalah hadiah dari rakyat: 100 emas dan 2000 perak.",
		"wait": "next"},
]
const TUTORIAL_REWARD := {"gold": 100, "silver": 2000}
## Pengenalan fitur yang muncul sekali saat fitur terbuka.
## Iklan berhadiah: jenis -> hadiah dan batas tonton per hari.
const AD_REWARDS := {
	"recruit": {"name": "Tiket Rekrut", "icon": "ticket_recruit", "reward": {"items": {"recruit_ticket": 1}}, "limit": 2},
	"refill": {"name": "Isi penuh urusan & energi", "icon": "item_tea", "reward": {}, "limit": 3},
	"gold": {"name": "Emas gratis", "icon": "gold", "reward": {"gold": 20}, "limit": 3},
}

## Menara Ujian: lantai bertingkat, dilawan dengan kekuatan tempur; reset tiap minggu.
const TOWER_UNLOCK_STAGE := 15
const TOWER_BASE := 80
const TOWER_GROWTH := 1.15
const TOWER_ATTEMPTS := 5  ## percobaan per hari (kalah memakai percobaan)


static func tower_floor(level: int) -> Dictionary:
	return {
		"power": int(TOWER_BASE * pow(TOWER_GROWTH, level - 1)),
		"silver": 500 + 200 * level,
		"gold": 5 + level / 2,
		"equip": level % 5 == 0,
		"rare": level % 10 == 0,
	}


const FEATURE_INTROS := [
	{"id": "alliance", "stage": ALLIANCE_UNLOCK_STAGE, "title": "Aliansi Terbuka!", "icon": "tab_alliance",
		"page": "alliance", "text": "Bergabunglah dengan aliansi untuk bonus hasil urusan kota, sumbangan harian, "
		+ "toko aliansi, dan bos mingguan Buto Ijo yang dilawan bersama."},
	{"id": "arena", "stage": ARENA_UNLOCK_STAGE, "title": "Arena Terbuka!", "icon": "tab_arena",
		"page": "arena", "text": "Tantang para tuan lain di Arena! Naikkan poin untuk mencapai liga lebih tinggi "
		+ "dan raih hadiah musim setiap minggu."},
	{"id": "tower", "stage": TOWER_UNLOCK_STAGE, "title": "Menara Ujian Terbuka!", "icon": "tower",
		"page": "campaign", "panel": "tower", "text": "Daki lantai demi lantai dengan kekuatan tempur penasihat. "
		+ "Tiap lantai ke-5 memberi pusaka. Kemajuan direset tiap minggu, rekor terbaik masuk peringkat."},
]
## Isi menu Panduan.
const HELP_TOPICS := [
	{"icon": "tab_city", "title": "Kota", "text": "Kerjakan urusan kota untuk perak, pangan, dan prajurit. "
		+ "Prajurit baru makan pangan, jadi kelola sawah juga. Urusan terisi 1 tiap menit. Kumpulkan prestise untuk naik jabatan: batas level dan hasil meningkat."},
	{"icon": "tab_counselor", "title": "Penasihat", "text": "Latih penasihat dengan perak. Kekuatan menentukan "
		+ "kampanye dan arena, Kecerdasan hasil pajak, Politik hasil sawah, Karisma jumlah prajurit."},
	{"icon": "tab_gacha", "title": "Rekrut", "text": "Rekrut penasihat dengan emas: Legenda 4%, Epik 21%. "
		+ "x10 dijamin Epik, Legenda dijamin dalam 50 tarikan. Duplikat menambah bintang."},
	{"icon": "tab_campaign", "title": "Kampanye", "text": "Kalahkan musuh tahap demi tahap. Korban bergantung "
		+ "pada kekuatan Anda dibanding musuh. Tiap tahap ke-5 memberi bonus emas."},
	{"icon": "tab_palace", "title": "Istana", "text": "Kunjungi selir untuk keakraban (+Karisma) dan peluang anak. "
		+ "Didik anak dengan pangan, lalu nikahkan untuk bonus atribut permanen."},
	{"icon": "tab_alliance", "title": "Aliansi", "text": "Terbuka di Tahap %d. Sumbang tiap hari, lawan bos "
		% ALLIANCE_UNLOCK_STAGE + "mingguan, dan belanja di toko aliansi dengan Jasa."},
	{"icon": "tab_arena", "title": "Arena", "text": "Terbuka di Tahap %d. Tantang lawan dengan tiket harian, naik "
		% ARENA_UNLOCK_STAGE + "liga, dan tukar koin arena di toko."},
	{"icon": "mission", "title": "Harian & Mingguan", "text": "Ambil hadiah login, selesaikan misi harian, dan "
		+ "kumpulkan poin event mingguan. Semuanya sumber emas utama."},
]

## Produk pembelian dalam aplikasi. id harus sama dengan ID produk di Google Play Console.
## type: "gold" (habis pakai, bonus x2 pembelian pertama), "card" (kartu bulanan, habis pakai),
## "once" (sekali beli). price_idr = harga cadangan bila harga dari Play belum termuat.
const IAP_PRODUCTS := [
	{"id": "starter_pack", "type": "once", "name": "Paket Pemula", "icon": "starter", "price_idr": 29000,
		"gold": 500, "silver": 50000, "soldiers": 20000, "counselor": "wening",
		"desc": "Sekali beli: 500 emas, 50.000 perak, 20.000 prajurit, dan penasihat Epik Wening Kirana."},
	{"id": "monthly_card", "type": "card", "name": "Kartu Bulanan", "icon": "card_monthly", "price_idr": 49000,
		"gold": 300, "daily_gold": 100, "days": 30,
		"desc": "Langsung 300 emas, lalu ambil 100 emas setiap hari selama 30 hari (total 3.300 emas)."},
	{"id": "gold_60", "type": "gold", "name": "60 Emas", "icon": "gold", "price_idr": 15000, "gold": 60, "bonus": 0},
	{"id": "gold_330", "type": "gold", "name": "330 Emas", "icon": "gold_pile", "price_idr": 75000, "gold": 300, "bonus": 30},
	{"id": "gold_680", "type": "gold", "name": "680 Emas", "icon": "gold_sack", "price_idr": 149000, "gold": 600, "bonus": 80},
	{"id": "gold_1380", "type": "gold", "name": "1.380 Emas", "icon": "chest_open", "price_idr": 299000, "gold": 1200, "bonus": 180},
	{"id": "gold_3280", "type": "gold", "name": "3.280 Emas", "icon": "gold_crown", "price_idr": 699000, "gold": 2800, "bonus": 480},
	{"id": "offer_promote", "type": "offer", "name": "Paket Naik Jabatan", "icon": "gold_crown", "price_idr": 29000,
		"desc": "Penawaran terbatas setelah naik jabatan."},
	{"id": "offer_rescue", "type": "offer", "name": "Paket Bala Bantuan", "icon": "soldiers", "price_idr": 15000,
		"desc": "Penawaran terbatas setelah kalah beruntun di kampanye."},
	{"id": "season_pass", "type": "pass", "name": "Tiket Musim Premium", "icon": "pass", "price_idr": 75000,
		"desc": "Buka jalur hadiah premium Tiket Musim ini: emas, Batu Bintang, Tiket Rekrut, dan pusaka Legenda."},
]

## Pencapaian bertingkat. metric: nama di GameModel.story_metric, atau "count:<event>"
## untuk penghitung aksi (GameModel.counters). Hadiah emas per tingkat (indeks 0..).
const ACHIEVEMENTS := [
	{"id": "conqueror", "name": "Penakluk", "icon": "tab_campaign", "metric": "stage", "text": "Menangkan tahap %s",
		"targets": [10, 25, 50, 75, 100]},
	{"id": "mighty", "name": "Kekuatan Besar", "icon": "power", "metric": "power", "text": "Capai kekuatan %s",
		"targets": [1000, 10000, 50000, 200000]},
	{"id": "collector", "name": "Kolektor Penasihat", "icon": "tab_counselor", "metric": "counselors",
		"text": "Miliki %s penasihat", "targets": [5, 10, 15, 19]},
	{"id": "stars", "name": "Bintang Terang", "icon": "star", "metric": "stars_total", "text": "Kumpulkan %s bintang penasihat",
		"targets": [5, 20, 50]},
	{"id": "family", "name": "Keluarga Besar", "icon": "heart", "metric": "children_total", "text": "Dikaruniai %s anak",
		"targets": [1, 10, 30, 60]},
	{"id": "climber", "name": "Pendaki Menara", "icon": "tower", "metric": "tower", "text": "Capai lantai %s Menara Ujian",
		"targets": [5, 15, 30]},
	{"id": "champion", "name": "Juara Arena", "icon": "tab_arena", "metric": "arena_wins", "text": "Menangi %s pertarungan arena",
		"targets": [10, 50, 200]},
	{"id": "recruiter", "name": "Perekrut", "icon": "tab_gacha", "metric": "count:recruit", "text": "Rekrut %s penasihat",
		"targets": [10, 100, 500]},
	{"id": "worker", "name": "Pekerja Keras", "icon": "tab_city", "metric": "count:affair", "text": "Kerjakan %s urusan kota",
		"targets": [100, 1000, 5000]},
	{"id": "keeper", "name": "Penjaga Pusaka", "icon": "eq_weapon", "metric": "equipment", "text": "Miliki %s pusaka",
		"targets": [1, 5, 15]},
	{"id": "generous", "name": "Dermawan", "icon": "tab_alliance", "metric": "count:donate", "text": "Sumbang ke aliansi %s kali",
		"targets": [10, 50, 200]},
	{"id": "hunter", "name": "Pemburu Bos", "icon": "jasa", "metric": "count:boss", "text": "Serang bos aliansi %s kali",
		"targets": [10, 50, 200]},
]
const ACHIEVEMENT_GOLD := [30, 60, 100, 150, 250]

## Paket terbatas waktu: berapa lama berlaku (detik) dan pemicu kekalahan beruntun.
const OFFER_SECONDS := {"offer_promote": 6 * 3600, "offer_rescue": 3 * 3600}
const OFFER_LOSS_STREAK := 3

## Tiket Musim (battle pass): musim 30 hari, 30 tingkat. XP dari aktivitas harian.
const PASS_DAYS := 30
const PASS_TIERS := 30
const PASS_XP_PER_TIER := 150
const PASS_XP := {"mission": 30, "chest": 20, "login": 20, "tower_win": 10, "arena": 5, "boss": 5}


## Hadiah tingkat `tier` (1..PASS_TIERS) di jalur gratis atau premium.
static func pass_reward(tier: int, premium: bool) -> Dictionary:
	if premium:
		if tier == PASS_TIERS:
			return {"gold": 300, "equip": "keris_nagasasra"}
		if tier % 10 == 0:
			return {"gold": 100, "items": {"star_stone": 2}}
		if tier % 5 == 0:
			return {"items": {"recruit_ticket": 2}}
		if tier % 3 == 0:
			return {"gold": 30, "items": {"energy_tea": 1}}
		return {"gold": 30}
	if tier % 10 == 0:
		return {"items": {"recruit_ticket": 1}}
	if tier % 5 == 0:
		return {"gold": 40}
	if tier % 2 == 0:
		return {"silver": 3000 + 300 * tier}
	return {"grain": 3000 + 300 * tier}

## VIP: poin dari pembelian (1 poin per Rp1.000) dan klaim login harian.
## perks bersifat total untuk level itu (bukan tambahan dari level sebelumnya):
## yield = bonus hasil urusan kota, charges = kapasitas urusan & energi kunjungan,
## arena_tickets / donations / boss_attacks = jatah harian tambahan.
## gift = hadiah naik level (langsung), daily = hadiah harian, pack = paket sekali beli dengan emas.
const VIP_IDR_PER_POINT := 1000
const VIP_LOGIN_POINTS := 1
const VIP_LEVELS := [
	{"points": 0, "perks": {}, "daily": {}, "gift": {}, "pack": {}},
	{"points": 15, "perks": {"yield": 0.02}, "daily": {"gold": 10, "silver": 2000}, "gift": {"gold": 30},
		"pack": {"cost": 60, "silver": 20000, "soldiers": 5000}},
	{"points": 50, "perks": {"yield": 0.04, "charges": 1}, "daily": {"gold": 15, "silver": 3000}, "gift": {"gold": 50},
		"pack": {"cost": 120, "grain": 30000, "soldiers": 10000}},
	{"points": 100, "perks": {"yield": 0.06, "charges": 1, "arena_tickets": 1}, "daily": {"gold": 20, "silver": 4000},
		"gift": {"gold": 80}, "pack": {"cost": 200, "silver": 60000, "grain": 40000}},
	{"points": 200, "perks": {"yield": 0.08, "charges": 1, "arena_tickets": 1, "donations": 1},
		"daily": {"gold": 25, "silver": 5000}, "gift": {"gold": 100}, "pack": {"cost": 300, "silver": 50000, "soldiers": 50000}},
	{"points": 400, "perks": {"yield": 0.10, "charges": 2, "arena_tickets": 1, "donations": 1},
		"daily": {"gold": 30, "silver": 6000}, "gift": {"gold": 150}, "pack": {"cost": 400, "silver": 50000, "counselor": "bagas"}},
	{"points": 700, "perks": {"yield": 0.12, "charges": 2, "arena_tickets": 2, "donations": 1, "war_attacks": 1},
		"daily": {"gold": 40, "silver": 8000}, "gift": {"gold": 200}, "pack": {"cost": 500, "soldiers": 100000, "grain": 80000}},
	{"points": 1200, "perks": {"yield": 0.14, "charges": 2, "arena_tickets": 2, "donations": 1, "boss_attacks": 1,
		"war_attacks": 1},
		"daily": {"gold": 50, "silver": 10000}, "gift": {"gold": 300}, "pack": {"cost": 700, "counselor": "kedaton"}},
	{"points": 2000, "perks": {"yield": 0.16, "charges": 3, "arena_tickets": 2, "donations": 2, "boss_attacks": 1,
		"war_attacks": 1},
		"daily": {"gold": 60, "silver": 12000}, "gift": {"gold": 400}, "pack": {"cost": 900, "silver": 200000, "soldiers": 150000}},
	{"points": 3500, "perks": {"yield": 0.18, "charges": 3, "arena_tickets": 3, "donations": 2, "boss_attacks": 1,
		"war_attacks": 1},
		"daily": {"gold": 80, "silver": 15000}, "gift": {"gold": 600}, "pack": {"cost": 1200, "counselor": "resi"}},
	{"points": 6000, "perks": {"yield": 0.20, "charges": 3, "arena_tickets": 3, "donations": 2, "boss_attacks": 2,
		"war_attacks": 2},
		"daily": {"gold": 100, "silver": 20000}, "gift": {"gold": 1000},
		"pack": {"cost": 1500, "silver": 500000, "grain": 300000, "soldiers": 300000}},
]
const VIP_PERK_NAMES := {
	"yield": "Hasil urusan kota +%d%%", "charges": "Kapasitas urusan & energi kunjungan +%d",
	"arena_tickets": "Tiket arena harian +%d", "donations": "Sumbangan aliansi harian +%d",
	"boss_attacks": "Serangan bos aliansi harian +%d", "war_attacks": "Serangan perang aliansi harian +%d",
}

## Leaderboard global (server disimulasikan: nilai pemain lain mengikuti distribusi
## log-normal/normal yang tumbuh seiring umur akun). dist: median & sigma pada hari ke-0,
## growth = pertumbuhan median per hari.
const LB_PLAYERS := 100000
const LB_TOP := 50
const LEADERBOARDS := [
	{"id": "power", "name": "Kekuatan", "icon": "power", "dist": "log", "median": 250.0, "sigma": 1.1, "growth": 0.06},
	{"id": "stage", "name": "Kampanye", "icon": "tab_campaign", "dist": "log", "median": 6.0, "sigma": 0.7, "growth": 0.05},
	{"id": "prestige", "name": "Prestise", "icon": "prestige", "dist": "log", "median": 150.0, "sigma": 1.2, "growth": 0.12},
	{"id": "arena", "name": "Arena", "icon": "tab_arena", "dist": "normal", "median": 1050.0, "sigma": 220.0, "growth": 0.002},
	{"id": "tower", "name": "Menara", "icon": "tower", "dist": "log", "median": 8.0, "sigma": 0.6, "growth": 0.04},
	{"id": "alliance", "name": "Aliansi", "icon": "tab_alliance"},
]
## Hadiah mingguan berdasarkan persentil Kekuatan di akhir minggu (top = batas persen, inklusif).
const LB_REWARDS := [
	{"top": 1.0, "name": "Top 1%", "gold": 300},
	{"top": 5.0, "name": "Top 5%", "gold": 200},
	{"top": 20.0, "name": "Top 20%", "gold": 100},
	{"top": 50.0, "name": "Top 50%", "gold": 50},
	{"top": 100.0, "name": "Peserta", "gold": 20},
]
const LB_ALLIANCE_COUNT := 30
const LB_ALLIANCE_WORDS := ["Naga", "Rajawali", "Banteng", "Kijang", "Elang", "Singa", "Merak", "Badak", "Harimau",
	"Gagak", "Kencana", "Wijaya", "Samudra", "Mahameru", "Surya", "Candra", "Bintang", "Pusaka", "Nusantara", "Dirgantara"]

## Item di tas. target: "counselor" / "beauty" / "" (tanpa target).
## Hadiah apa pun bisa berisi {"items": {id: jumlah}}.
const ITEMS := {
	"scroll_train": {"name": "Gulungan Latihan", "icon": "item_scroll", "target": "counselor",
		"desc": "Penasihat pilihan naik 1 level tanpa biaya (tetap mengikuti batas jabatan)."},
	"star_stone": {"name": "Batu Bintang", "icon": "item_star", "target": "counselor",
		"desc": "Penasihat pilihan +1 bintang (+20% atribut)."},
	"pill_intimacy": {"name": "Pil Keakraban", "icon": "item_pill", "target": "beauty",
		"desc": "Keakraban selir pilihan +10."},
	"recruit_ticket": {"name": "Tiket Rekrut", "icon": "ticket_recruit", "target": "",
		"desc": "Rekrut 1 penasihat tanpa emas (pakai di halaman Rekrut)."},
	"energy_tea": {"name": "Teh Semangat", "icon": "item_tea", "target": "",
		"desc": "Mengisi penuh semua urusan kota dan energi kunjungan."},
	"silver_box": {"name": "Peti Perak", "icon": "silver", "target": "", "desc": "Berisi 10.000 perak.",
		"open": {"silver": 10000}},
	"grain_box": {"name": "Karung Pangan", "icon": "grain", "target": "", "desc": "Berisi 10.000 pangan.",
		"open": {"grain": 10000}},
	"troop_writ": {"name": "Surat Wajib Militer", "icon": "soldiers", "target": "", "desc": "Berisi 5.000 prajurit.",
		"open": {"soldiers": 5000}},
}
const ITEM_ORDER := ["recruit_ticket", "star_stone", "scroll_train", "pill_intimacy", "energy_tea", "silver_box",
	"grain_box", "troop_writ"]
## Item acak dari tahap besar kampanye (tiap tahap ke-5).
const STAGE_ITEM_POOL := ["scroll_train", "scroll_train", "pill_intimacy", "energy_tea", "silver_box", "troop_writ",
	"recruit_ticket"]

## Cerita & misi utama. Progres misi dihitung dari keadaan game (lihat story_progress).
## type: stage, power, rank, counselors, max_level, prestige, children_total, intimacy,
## alliance, arena_wins, officials, stars_total.
const STORY_CHAPTERS := [
	{"title": "Kepala Desa yang Baru", "story": [
		{"speaker": "sekar", "text": "Tuan, desa ini sudah lama tanpa pemimpin. Begal menjarah lumbung, rakyat ketakutan."},
		{"speaker": "arya", "text": "Beri saya prajurit, Tuan. Saya akan mengusir para begal dari perbatasan desa!"},
		{"speaker": "lord", "text": "Mulai hari ini, desa ini di bawah perlindunganku. Kita bangun kembali bersama."}],
		"quests": [
			{"type": "stage", "target": 1, "text": "Usir begal: menangkan Tahap 1", "reward": {"gold": 30, "silver": 1000}},
			{"type": "max_level", "target": 3, "text": "Latih seorang penasihat ke level 3", "reward": {"silver": 2000}},
			{"type": "power", "target": 80, "text": "Capai kekuatan 80", "reward": {"items": {"scroll_train": 1}}},
		], "reward": {"gold": 100, "items": {"recruit_ticket": 1}}},
	{"title": "Tangan Besi", "story": [
		{"speaker": "bayu", "text": "Kabar Tuan sampai ke kota kecamatan. Para pejabat menunggu bukti kepemimpinan Tuan."},
		{"speaker": "sekar", "text": "Kumpulkan penasihat yang cakap dan buktikan diri di medan perang. Jabatan Camat menanti."}],
		"quests": [
			{"type": "stage", "target": 5, "text": "Taklukkan Tahap 5", "reward": {"gold": 50}},
			{"type": "counselors", "target": 4, "text": "Miliki 4 penasihat", "reward": {"silver": 5000}},
			{"type": "prestige", "target": 300, "text": "Kumpulkan 300 prestise", "reward": {"items": {"energy_tea": 1}}},
			{"type": "rank", "target": 1, "text": "Naik jabatan menjadi Camat", "reward": {"gold": 80}},
		], "reward": {"gold": 150, "items": {"star_stone": 1}}},
	{"title": "Keluarga Bangsawan", "story": [
		{"speaker": "melati", "text": "Tuan selalu sibuk dengan urusan negeri. Istana terasa sepi tanpa tawa anak-anak."},
		{"speaker": "ratna", "text": "Para bangsawan menghormati tuan yang punya keluarga dan sekutu. Aliansi akan memperkuat kita."}],
		"quests": [
			{"type": "children_total", "target": 1, "text": "Dikaruniai seorang anak", "reward": {"grain": 5000}},
			{"type": "intimacy", "target": 20, "text": "Capai total keakraban 20", "reward": {"items": {"pill_intimacy": 2}}},
			{"type": "alliance", "target": 1, "text": "Bergabung dengan aliansi", "reward": {"gold": 80}},
			{"type": "stage", "target": 8, "text": "Taklukkan Tahap 8", "reward": {"soldiers": 10000}},
		], "reward": {"gold": 200, "items": {"recruit_ticket": 2}}},
	{"title": "Panggung Bupati", "story": [
		{"speaker": "dewi", "text": "Kabupaten ini butuh pemimpin yang disegani di arena dan didukung pejabat yang setia."},
		{"speaker": "gajah", "text": "Para tuan dari seluruh negeri berlaga di arena. Tunjukkan kekuatan kita, Tuan!"}],
		"quests": [
			{"type": "rank", "target": 2, "text": "Naik jabatan menjadi Bupati", "reward": {"gold": 100}},
			{"type": "power", "target": 1000, "text": "Capai kekuatan 1.000", "reward": {"items": {"scroll_train": 3}}},
			{"type": "arena_wins", "target": 3, "text": "Menangi 3 pertarungan arena", "reward": {"silver": 15000}},
			{"type": "officials", "target": 1, "text": "Angkat seorang anak menjadi pejabat", "reward": {"gold": 100}},
		], "reward": {"gold": 300, "items": {"star_stone": 1, "recruit_ticket": 2}}},
	{"title": "Badai di Perbatasan", "story": [
		{"speaker": "enemy_warlord", "text": "Hahaha! Tanah ini akan menjadi milik Panglima Lalim! Siapa yang berani menghalangiku?"},
		{"speaker": "satria", "text": "Saya, Tuan. Bersama pasukan dan para penasihat terbaik, kita hancurkan pemberontakan ini."}],
		"quests": [
			{"type": "stage", "target": 20, "text": "Hancurkan pemberontakan: Tahap 20", "reward": {"gold": 150}},
			{"type": "rank", "target": 3, "text": "Naik jabatan menjadi Gubernur", "reward": {"gold": 150}},
			{"type": "stars_total", "target": 5, "text": "Kumpulkan total 5 bintang penasihat", "reward": {"items": {"star_stone": 1}}},
		], "reward": {"gold": 400, "items": {"recruit_ticket": 3}}},
	{"title": "Menuju Istana Raja", "story": [
		{"speaker": "resi", "text": "Negeri ini menanti pemimpin yang bijak. Jalan menuju istana raja terbuka bagi Tuan."},
		{"speaker": "kedaton", "text": "Buktikan bahwa Tuan layak menjadi tangan kanan raja: Perdana Menteri negeri ini."}],
		"quests": [
			{"type": "stage", "target": 40, "text": "Taklukkan Tahap 40", "reward": {"gold": 200}},
			{"type": "power", "target": 10000, "text": "Capai kekuatan 10.000", "reward": {"items": {"star_stone": 2}}},
			{"type": "rank", "target": 5, "text": "Menjadi Perdana Menteri", "reward": {"gold": 300}},
		], "reward": {"gold": 1000, "items": {"star_stone": 3, "recruit_ticket": 5}}},
	{"title": "Patih Negeri", "story": [
		{"speaker": "kedaton", "text": "Raja mempercayakan urusan seluruh negeri kepada Tuan. Gelar Patih menanti mereka yang teruji."},
		{"speaker": "tantular", "text": "Ujilah diri Tuan di Menara Ujian, dan kumpulkan pusaka para leluhur."}],
		"quests": [
			{"type": "stage", "target": 50, "text": "Taklukkan Tahap 50", "reward": {"gold": 300}},
			{"type": "tower", "target": 10, "text": "Capai lantai 10 Menara Ujian", "reward": {"items": {"star_stone": 2}}},
			{"type": "equipment", "target": 3, "text": "Miliki 3 pusaka", "reward": {"silver": 100000}},
		], "reward": {"gold": 1200, "items": {"recruit_ticket": 5}}},
	{"title": "Sumpah Mahapatih", "story": [
		{"speaker": "lord", "text": "Aku bersumpah tidak akan beristirahat sebelum seluruh Nusantara bersatu!"},
		{"speaker": "gajah", "text": "Sumpah Tuan menggetarkan para raja. Mari kita wujudkan bersama, Mahapatih!"}],
		"quests": [
			{"type": "stage", "target": 65, "text": "Taklukkan Tahap 65", "reward": {"gold": 400}},
			{"type": "tower", "target": 25, "text": "Capai lantai 25 Menara Ujian", "reward": {"items": {"star_stone": 3}}},
			{"type": "power", "target": 100000, "text": "Capai kekuatan 100.000", "reward": {"gold": 500}},
			{"type": "equip_level", "target": 6, "text": "Tingkatkan satu pusaka ke +5", "reward": {"silver": 300000}},
		], "reward": {"gold": 2000, "items": {"star_stone": 5, "recruit_ticket": 10}}},
]
## Gelar kehormatan setelah menamatkan bab tertentu (jumlah bab tamat) dan bonus
## semua hasil urusan kota. Gelar tertinggi menggantikan nama jabatan di header.
const HONOR_TITLES := [
	{"chapters": 7, "name": "Patih", "bonus": 0.05},
	{"chapters": 8, "name": "Mahapatih", "bonus": 0.10},
]
const STORY_SPEAKER_NAMES := {"lord": "Anda", "enemy_warlord": "Panglima Lalim"}

const REWARD_KEYS := ["gold", "silver", "grain", "soldiers"]
const REWARD_NAMES := {"gold": "emas", "silver": "perak", "grain": "pangan", "soldiers": "prajurit", "jasa": "jasa"}


static func counselor_def(id: String) -> Dictionary:
	for c in COUNSELORS:
		if c["id"] == id:
			return c
	return {}


static func counselors_of_rarity(rarity: String) -> Array:
	return COUNSELORS.filter(func(c): return c["rarity"] == rarity)


static func mission_def(id: String) -> Dictionary:
	for m in DAILY_MISSIONS:
		if m["id"] == id:
			return m
	return {}


static func alliance_def(id: String) -> Dictionary:
	for a in ALLIANCES:
		if a["id"] == id:
			return a
	return {}


static func shop_def(id: String) -> Dictionary:
	for item in ALLIANCE_SHOP + ARENA_SHOP:
		if item["id"] == id:
			return item
	return {}


static func leaderboard_def(id: String) -> Dictionary:
	for lb in LEADERBOARDS:
		if lb["id"] == id:
			return lb
	return {}


static func iap_def(id: String) -> Dictionary:
	for p in IAP_PRODUCTS:
		if p["id"] == id:
			return p
	return {}


## Format rupiah: 75000 -> "Rp75.000".
static func format_idr(amount: int) -> String:
	var digits := str(amount)
	var out := ""
	while digits.length() > 3:
		out = "." + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return "Rp" + digits + out


static func league_of(rating: int) -> Dictionary:
	var out: Dictionary = ARENA_LEAGUES[0]
	for l in ARENA_LEAGUES:
		if rating >= int(l["min"]):
			out = l
	return out


static func beauty_def(id: String) -> Dictionary:
	for b in BEAUTIES:
		if b["id"] == id:
			return b
	return {}


## Tahap kampanye dibuat prosedural supaya tidak ada batas akhir.
## Biaya latih penasihat: UPGRADE_COST_BASE * level^UPGRADE_COST_EXP perak.
const UPGRADE_COST_BASE := 50
const UPGRADE_COST_EXP := 2.0

## Kurva kampanye: jumlah & kekuatan musuh tumbuh eksponensial per tahap.
const STAGE_SOLDIERS_BASE := 600
const STAGE_SOLDIERS_GROWTH := 1.16
const STAGE_STR_BASE := 12
const STAGE_STR_GROWTH := 1.13
## Rasio korban minimum walau kekuatan Anda jauh di atas musuh.
const LOSS_RATIO_MIN := 0.5
## Formasi pasukan: pilihan taktik sebelum perang. "power" mengubah kekuatan tempur
## (arena, menara, bos, perang), "losses" korban kampanye, "prestige" prestise kampanye.
const FORMATIONS := {
	"balanced": {"name": "Seimbang", "icon": "formation_balanced", "power": 0.0, "losses": 0.0, "prestige": 0.0,
		"desc": "Tanpa bonus maupun kelemahan."},
	"assault": {"name": "Serbu", "icon": "formation_assault", "power": 0.06, "losses": 0.12, "prestige": 0.10,
		"desc": "Kekuatan tempur +6%, prestise kampanye +10%, tetapi korban +12%."},
	"defense": {"name": "Bertahan", "icon": "formation_defense", "power": -0.06, "losses": -0.12, "prestige": 0.0,
		"desc": "Korban kampanye -12%, tetapi kekuatan tempur -6%."},
}
const FORMATION_ORDER := ["balanced", "assault", "defense"]
## Tahap kampanye yang ditayangkan sebagai perang penuh (tahap besar = tiap tahap ke-5).
const BATTLE_FULL_EVERY := 5


static func stage_info(index: int) -> Dictionary:
	var enemy: Dictionary = ENEMIES[index % ENEMIES.size()]
	return {
		"name": "Tahap %d" % (index + 1),
		"enemy_id": enemy["id"],
		"enemy_name": enemy["name"],
		"enemy_soldiers": int(STAGE_SOLDIERS_BASE * pow(STAGE_SOLDIERS_GROWTH, index)),
		"enemy_str": int(STAGE_STR_BASE * pow(STAGE_STR_GROWTH, index)),
		"reward_silver": 120 + 45 * index,
		"reward_prestige": 10 + 4 * index,
		# Tiap tahap ke-5 adalah tahap besar dengan bonus emas.
		"reward_gold": 15 + 3 * int(index / 5.0) + (50 if (index + 1) % 5 == 0 else 0),
	}


## Ringkasan kebijakan privasi di dalam game (versi lengkap: docs/privacy_policy.md).
const PRIVACY_SECTIONS := [
	{"title": "Data di perangkat Anda", "text": "Progres game (save.json), pengaturan, statistik bermain, dan "
		+ "laporan crash disimpan hanya di penyimpanan aplikasi pada perangkat ini. Game tidak memiliki akun "
		+ "atau server dan tidak mengirim data ini ke mana pun."},
	{"title": "Pemain lain", "text": "Anggota aliansi, lawan arena, chat, dan papan peringkat adalah simulasi "
		+ "di perangkat Anda. Pesan chat yang Anda ketik tidak dikirim ke siapa pun."},
	{"title": "Pembelian dalam aplikasi", "text": "Pembayaran diproses oleh Google Play. Game hanya menerima "
		+ "konfirmasi pembelian (ID produk dan token), tidak pernah data kartu atau rekening Anda."},
	{"title": "Iklan berhadiah", "text": "Iklan hanya diputar bila Anda menekan tombol Iklan. Versi dengan "
		+ "Google AdMob dapat memakai ID iklan perangkat untuk menampilkan dan mengukur iklan sesuai kebijakan Google."},
	{"title": "Notifikasi", "text": "Pengingat dijadwalkan secara lokal oleh perangkat. Matikan kapan saja di "
		+ "Pengaturan atau pengaturan Android."},
	{"title": "Laporan masalah", "text": "Tombol Salin Laporan hanya menyalin teks ke clipboard. Anda yang "
		+ "memutuskan apakah akan mengirimkannya ke pengembang."},
	{"title": "Menghapus data", "text": "Hapus Statistik menghapus statistik bermain. Mulai Ulang menghapus "
		+ "progres. Menghapus aplikasi menghapus semua data game dari perangkat."},
]
