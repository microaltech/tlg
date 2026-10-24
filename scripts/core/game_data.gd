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
	{"name": "Camat", "prestige": 150, "max_charges": 4, "mult": 1.25, "level_cap": 40, "child_seats": 3},
	{"name": "Bupati", "prestige": 600, "max_charges": 5, "mult": 1.5, "level_cap": 60, "child_seats": 4},
	{"name": "Gubernur", "prestige": 1800, "max_charges": 6, "mult": 2.0, "level_cap": 80, "child_seats": 5},
	{"name": "Menteri", "prestige": 5000, "max_charges": 7, "mult": 2.5, "level_cap": 100, "child_seats": 6},
	{"name": "Perdana Menteri", "prestige": 12000, "max_charges": 8, "mult": 3.0, "level_cap": 150, "child_seats": 8},
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
]

const BEAUTIES := [
	{"id": "melati", "name": "Melati", "unlock_stage": 0},
	{"id": "kenanga", "name": "Kenanga", "unlock_stage": 5},
	{"id": "anggrek", "name": "Anggrek", "unlock_stage": 12},
	{"id": "cempaka", "name": "Cempaka", "unlock_stage": 20},
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

## Misi harian: tiap hari dipilih DAILY_COUNT misi acak dari kumpulan ini.
## event = aksi yang dihitung; requires = syarat agar misi boleh muncul.
## Hadiah memakai kunci gold/silver/grain/soldiers.
const DAILY_COUNT := 5
const DAILY_POINTS := 20  ## Poin aktivitas per misi yang diklaim.
const DAILY_MISSIONS := [
	{"id": "affair10", "text": "Kerjakan urusan kota 10 kali", "event": "affair", "target": 10, "gold": 20, "silver": 500},
	{"id": "tax5", "text": "Tarik pajak 5 kali", "event": "affair_silver", "target": 5, "gold": 20, "grain": 500},
	{"id": "farm5", "text": "Kelola sawah 5 kali", "event": "affair_grain", "target": 5, "gold": 20, "silver": 500},
	{"id": "troops5", "text": "Rekrut prajurit 5 kali", "event": "affair_soldiers", "target": 5, "gold": 20, "grain": 500},
	{"id": "upgrade5", "text": "Latih penasihat 5 kali", "event": "upgrade", "target": 5, "gold": 30, "silver": 800},
	{"id": "win3", "text": "Menangkan 3 tahap kampanye", "event": "win", "target": 3, "gold": 40, "soldiers": 1000},
	{"id": "visit3", "text": "Kunjungi selir 3 kali", "event": "visit", "target": 3, "gold": 25, "grain": 600},
	{"id": "train3", "text": "Didik anak 3 kali", "event": "train", "target": 3, "gold": 25, "silver": 600, "requires": "children"},
	{"id": "gacha1", "text": "Rekrut penasihat 1 kali", "event": "recruit", "target": 1, "gold": 30, "silver": 500},
	{"id": "silver3k", "text": "Kumpulkan 3000 perak dari pajak", "event": "earn_silver", "target": 3000, "gold": 30, "grain": 800},
	{"id": "donate1", "text": "Sumbang ke aliansi 1 kali", "event": "donate", "target": 1, "gold": 25, "silver": 500, "requires": "alliance"},
	{"id": "boss2", "text": "Serang bos aliansi 2 kali", "event": "boss", "target": 2, "gold": 30, "soldiers": 800, "requires": "alliance"},
	{"id": "arena3", "text": "Bertarung di arena 3 kali", "event": "arena", "target": 3, "gold": 30, "silver": 800, "requires": "arena"},
]
## Peti aktivitas: terbuka saat poin harian mencapai batas.
const DAILY_CHESTS := [
	{"points": 40, "gold": 30, "silver": 1000},
	{"points": 80, "gold": 50, "grain": 1500},
	{"points": 100, "gold": 100, "soldiers": 2000},
]
## Hadiah login harian (7 hari berturut-turut). Terlewat sehari = kembali ke Hari 1.
const LOGIN_REWARDS := [
	{"gold": 50, "silver": 1000},
	{"grain": 2000, "soldiers": 1000},
	{"gold": 80},
	{"silver": 3000, "grain": 2000},
	{"gold": 100, "soldiers": 2000},
	{"silver": 5000, "grain": 3000},
	{"gold": 300, "soldiers": 5000},
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
		"points": {"win": 60, "upgrade": 15, "boss": 20, "arena_win": 40}, "bonus": {"losses": -0.2},
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
	"arena_win": "Menang di arena",
}
const EVENT_MISSION_POINTS := 50  ## Poin event untuk tiap misi harian yang diklaim.
const EVENT_TIERS := [
	{"points": 100, "gold": 30, "silver": 1000},
	{"points": 300, "grain": 3000, "soldiers": 2000},
	{"points": 600, "gold": 80},
	{"points": 1000, "silver": 8000, "grain": 5000},
	{"points": 1500, "gold": 150, "soldiers": 5000},
	{"points": 2200, "silver": 15000, "grain": 10000},
	{"points": 3000, "gold": 400},
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
	{"id": "gold30", "name": "Kantong Emas", "icon": "gold", "reward": {"gold": 30}, "cost": 100, "limit": 2, "level": 1},
	{"id": "silver10k", "name": "Peti Perak", "icon": "silver", "reward": {"silver": 10000}, "cost": 80, "limit": 3, "level": 1},
	{"id": "grain10k", "name": "Lumbung Pangan", "icon": "grain", "reward": {"grain": 10000}, "cost": 80, "limit": 3, "level": 2},
	{"id": "soldiers5k", "name": "Pasukan Bantuan", "icon": "soldiers", "reward": {"soldiers": 5000}, "cost": 120, "limit": 2, "level": 3},
	{"id": "gold100", "name": "Peti Emas Besar", "icon": "chest", "reward": {"gold": 100}, "cost": 300, "limit": 1, "level": 5},
]
const BOSS_NAME := "Buto Ijo"
const BOSS_ATTACKS_PER_DAY := 3
const BOSS_DAMAGE_PER_POWER := 25  ## Kerusakan pemain per serangan = kekuatan x ini (±10%).
const BOSS_NPC_DAMAGE_PER_POWER := 8  ## Kerusakan harian tiap anggota NPC.
const BOSS_HP_DAYS := 5.5  ## Tanpa bantuan pemain, NPC mengalahkan bos dalam ~5,5 hari.
const BOSS_ATTACK_JASA := 20
const BOSS_REWARD := {"gold": 100, "jasa": 200}
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
	{"id": "a_gold", "name": "Kantong Emas", "icon": "gold", "reward": {"gold": 40}, "cost": 100, "limit": 2},
	{"id": "a_silver", "name": "Peti Perak", "icon": "silver", "reward": {"silver": 15000}, "cost": 60, "limit": 3},
	{"id": "a_grain", "name": "Lumbung Pangan", "icon": "grain", "reward": {"grain": 15000}, "cost": 60, "limit": 3},
	{"id": "a_soldiers", "name": "Pasukan Bayaran", "icon": "soldiers", "reward": {"soldiers": 8000}, "cost": 80, "limit": 3},
]
## Potret yang dipakai sebagai avatar lawan arena.
const ARENA_AVATARS := ["arya", "sekar", "bayu", "ratna", "gajah", "lintang", "danu", "wening", "bagas",
	"enemy_bandit", "enemy_rebel", "enemy_pirate"]

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
static func stage_info(index: int) -> Dictionary:
	var enemy: Dictionary = ENEMIES[index % ENEMIES.size()]
	return {
		"name": "Tahap %d" % (index + 1),
		"enemy_id": enemy["id"],
		"enemy_name": enemy["name"],
		"enemy_soldiers": int(300 * pow(1.16, index)),
		"enemy_str": int(12 * pow(1.13, index)),
		"reward_silver": 120 + 45 * index,
		"reward_prestige": 10 + 4 * index,
		# Tiap tahap ke-5 adalah tahap besar dengan bonus emas.
		"reward_gold": 15 + 3 * int(index / 5.0) + (50 if (index + 1) % 5 == 0 else 0),
	}
