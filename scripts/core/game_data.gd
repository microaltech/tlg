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
const REWARD_KEYS := ["gold", "silver", "grain", "soldiers"]
const REWARD_NAMES := {"gold": "emas", "silver": "perak", "grain": "pangan", "soldiers": "prajurit"}


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
