// Server sosial Tuan Nusantara: akun perangkat, profil pemain, papan peringkat,
// chat aliansi, arena melawan pemain sungguhan, teman & hadiah, Raja Hari Ini,
// dan Perang Wilayah Aliansi mingguan.
//
// Tanpa dependensi luar: Node.js >= 22.13 (node:http + node:sqlite).
//   node server/server.js                 # port 8080, data di server/data/tlg.db
//   PORT=9000 DB_PATH=/data/tlg.db node server/server.js
//
// Semua respons JSON. Endpoint bertanda (auth) butuh header
// "Authorization: Bearer <token>" dari /v1/auth/device.
//
// Batasan versi ini: profil (kekuatan, tahap) dilaporkan oleh klien, jadi bisa
// dipalsukan. Untuk rilis kompetitif, logika ekonomi harus pindah ke server
// (lihat docs/server_design.md). Hasil arena sudah dihitung di server.

"use strict";
const http = require("node:http");
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const { DatabaseSync } = require("node:sqlite");

const ALLIANCES = ["garuda", "teratai", "macan"];
const LEADERBOARDS = ["power", "stage", "tower", "prestige"];
const NAME_MAX = 16;
const CHAT_MAX = 120;
const CHAT_COOLDOWN_MS = 2000;
const CHAT_KEEP = 200; // pesan per aliansi yang disimpan
const ARENA_START = 1000;
const REPORT_HIDE = 3; // laporan dari pemain berbeda sebelum pesan disembunyikan
const ARENA_K = 32;
const FRIENDS_MAX = 50;
const GIFT_CLAIM_DAILY = 10;
const DECREES = ["perak", "pangan", "prajurit", "berkah"];
const GUILDWAR_ATTACKS = 3;
const TERRITORIES = ["Selat Sunda", "Teluk Bone", "Laut Banda", "Tanah Karo", "Lembah Baliem", "Danau Toba"];
const DAY_MS = 86400000;
const BOSS_ATTACKS = 3;
const TOURNEY_SIZE = 16;
const BADGE_IDS = ["pemburu", "joki", "cendekia", "penjelajah", "diplomat", "empu", "panglima", "dalang"];
const BOSS_HP_MIN = 200000;
const CODE_LIMITS = { gold: 1000, silver: 10000000, grain: 10000000, soldiers: 10000000, prestige: 2000 };
const CODE_ITEMS = ["scroll_train", "star_stone", "pill_intimacy", "recruit_ticket", "energy_tea", "silver_box",
	"grain_box", "troop_writ", "besi_tempa", "kayu_cendana", "batu_meteor"];
const BANNED = ["anjing", "bangsat", "babi", "kontol", "memek", "goblok", "tolol", "bajingan", "kampret", "asu",
	"fuck", "shit", "bitch", "bastard", "asshole"];

function openDb(file) {
	if (file !== ":memory:") fs.mkdirSync(path.dirname(file), { recursive: true });
	const db = new DatabaseSync(file);
	db.exec(`
		PRAGMA journal_mode = WAL;
		CREATE TABLE IF NOT EXISTS players (
			id TEXT PRIMARY KEY, device_hash TEXT UNIQUE NOT NULL, token TEXT UNIQUE NOT NULL,
			name TEXT NOT NULL, portrait TEXT NOT NULL DEFAULT 'lord', frame TEXT NOT NULL DEFAULT 'frame_kayu',
			alliance TEXT, power INTEGER NOT NULL DEFAULT 0, stage INTEGER NOT NULL DEFAULT 0,
			tower INTEGER NOT NULL DEFAULT 0, prestige INTEGER NOT NULL DEFAULT 0,
			rating INTEGER NOT NULL DEFAULT ${ARENA_START}, created INTEGER NOT NULL, seen INTEGER NOT NULL);
		CREATE TABLE IF NOT EXISTS chat (
			id INTEGER PRIMARY KEY AUTOINCREMENT, alliance TEXT NOT NULL, player TEXT NOT NULL,
			name TEXT NOT NULL, portrait TEXT NOT NULL, text TEXT NOT NULL, t INTEGER NOT NULL,
			hidden INTEGER NOT NULL DEFAULT 0);
		CREATE TABLE IF NOT EXISTS reports (
			message INTEGER NOT NULL, reporter TEXT NOT NULL, t INTEGER NOT NULL, PRIMARY KEY (message, reporter));
		CREATE INDEX IF NOT EXISTS chat_alliance ON chat(alliance, id);
		CREATE TABLE IF NOT EXISTS arena_log (
			id INTEGER PRIMARY KEY AUTOINCREMENT, attacker TEXT NOT NULL, defender TEXT NOT NULL,
			win INTEGER NOT NULL, delta INTEGER NOT NULL, t INTEGER NOT NULL);
		CREATE TABLE IF NOT EXISTS friends (
			a TEXT NOT NULL, b TEXT NOT NULL, t INTEGER NOT NULL, PRIMARY KEY (a, b));
		CREATE TABLE IF NOT EXISTS gifts (
			id INTEGER PRIMARY KEY AUTOINCREMENT, sender TEXT NOT NULL, receiver TEXT NOT NULL,
			day INTEGER NOT NULL, claimed INTEGER NOT NULL DEFAULT 0, UNIQUE (sender, receiver, day));
		CREATE TABLE IF NOT EXISTS kings (
			day INTEGER PRIMARY KEY, player TEXT NOT NULL, name TEXT NOT NULL, portrait TEXT NOT NULL,
			frame TEXT NOT NULL, power INTEGER NOT NULL, decree TEXT);
		CREATE TABLE IF NOT EXISTS guildwar (
			week INTEGER NOT NULL, territory INTEGER NOT NULL, alliance TEXT NOT NULL, points INTEGER NOT NULL,
			PRIMARY KEY (week, territory, alliance));
		CREATE TABLE IF NOT EXISTS guildwar_attacks (
			player TEXT NOT NULL, day INTEGER NOT NULL, n INTEGER NOT NULL, PRIMARY KEY (player, day));
		CREATE TABLE IF NOT EXISTS world_boss (
			week INTEGER PRIMARY KEY, hp_max INTEGER NOT NULL, damage INTEGER NOT NULL DEFAULT 0);
		CREATE TABLE IF NOT EXISTS world_boss_hits (
			week INTEGER NOT NULL, player TEXT NOT NULL, damage INTEGER NOT NULL DEFAULT 0,
			day INTEGER NOT NULL DEFAULT -1, n INTEGER NOT NULL DEFAULT 0, PRIMARY KEY (week, player));
		CREATE TABLE IF NOT EXISTS codes (
			code TEXT PRIMARY KEY, reward TEXT NOT NULL, max_uses INTEGER NOT NULL, uses INTEGER NOT NULL DEFAULT 0,
			expires INTEGER NOT NULL);
		CREATE TABLE IF NOT EXISTS tourney_entries (
			week INTEGER NOT NULL, player TEXT NOT NULL, power INTEGER NOT NULL, PRIMARY KEY (week, player));
		CREATE TABLE IF NOT EXISTS tourney_results (week INTEGER PRIMARY KEY, bracket TEXT NOT NULL);
		CREATE TABLE IF NOT EXISTS mail (
			id INTEGER PRIMARY KEY AUTOINCREMENT, target TEXT NOT NULL, title TEXT NOT NULL, body TEXT NOT NULL,
			reward TEXT NOT NULL, created INTEGER NOT NULL, expires INTEGER NOT NULL);
		CREATE TABLE IF NOT EXISTS mail_claims (mail INTEGER NOT NULL, player TEXT NOT NULL, t INTEGER NOT NULL,
			PRIMARY KEY (mail, player));
		CREATE TABLE IF NOT EXISTS stats_reports (
			install TEXT NOT NULL, day INTEGER NOT NULL, payload TEXT NOT NULL, PRIMARY KEY (install, day));
		CREATE TABLE IF NOT EXISTS redemptions (
			code TEXT NOT NULL, player TEXT NOT NULL, t INTEGER NOT NULL, PRIMARY KEY (code, player));
	`);
	// Kolom tambahan versi lebih baru (database lama di-upgrade di tempat).
	const cols = db.prepare("PRAGMA table_info(players)").all().map((c) => c.name);
	if (!cols.includes("city")) db.exec("ALTER TABLE players ADD COLUMN city TEXT NOT NULL DEFAULT '{}'");
	return db;
}

function cleanName(raw) {
	const name = String(raw || "").replace(/[\u0000-\u001f<>]/g, "").trim().slice(0, NAME_MAX);
	return name.length >= 2 ? name : "Tuan";
}

function filterText(text) {
	let out = text;
	for (const w of BANNED) out = out.replace(new RegExp(w, "gi"), "*".repeat(w.length));
	return out;
}

// Hadiah kode dibatasi: hanya sumber daya dan item yang dikenal, dengan batas jumlah.
function cleanReward(raw) {
	const out = {};
	for (const [k, max] of Object.entries(CODE_LIMITS)) if (raw && raw[k] != null) out[k] = clampInt(raw[k], 0, max);
	if (raw && raw.items && typeof raw.items === "object") {
		out.items = {};
		for (const id of CODE_ITEMS) if (raw.items[id] != null) out.items[id] = clampInt(raw.items[id], 0, 10);
	}
	return out;
}

// Statistik anonim: hanya angka dan nama kejadian yang dikenal, tanpa teks bebas.
const STAT_EVENTS = /^[a-z_]{1,24}$/;
function cleanStats(raw) {
	const out = { version: String(raw.version || "").slice(0, 16), sessions: clampInt(raw.sessions, 0, 1e6),
		play_seconds: clampInt(raw.play_seconds, 0, 1e9), days: clampInt(raw.days, 0, 1e5), stage: clampInt(raw.stage, 0, 1e6),
		rank: clampInt(raw.rank, 0, 20), tutorial_done: !!raw.tutorial_done, language: String(raw.language || "").slice(0, 5),
		events: {} };
	if (raw.events && typeof raw.events === "object") {
		for (const [k, v] of Object.entries(raw.events).slice(0, 100)) if (STAT_EVENTS.test(k)) out.events[k] = clampInt(v, 0, 1e9);
	}
	return out;
}

function addMail(db, target, title, body, reward, days, t = Date.now()) {
	db.prepare("INSERT INTO mail (target, title, body, reward, created, expires) VALUES (?, ?, ?, ?, ?, ?)")
		.run(target, String(title).slice(0, 60), String(body).slice(0, 500), JSON.stringify(cleanReward(reward)), t,
			t + days * 86400000);
}

function clampInt(v, lo, hi) {
	const n = Math.floor(Number(v));
	return Number.isFinite(n) ? Math.min(hi, Math.max(lo, n)) : lo;
}

function createServer(opts = {}) {
	const db = openDb(opts.dbPath || ":memory:");
	const now = opts.now || (() => Date.now());
	const random = opts.random || Math.random;
	const lastChat = new Map();

	const q = {
		byDevice: db.prepare("SELECT * FROM players WHERE device_hash = ?"),
		byToken: db.prepare("SELECT * FROM players WHERE token = ?"),
		byId: db.prepare("SELECT * FROM players WHERE id = ?"),
		insert: db.prepare(`INSERT INTO players (id, device_hash, token, name, created, seen)
			VALUES (?, ?, ?, ?, ?, ?)`),
		seen: db.prepare("UPDATE players SET seen = ? WHERE id = ?"),
		profile: db.prepare(`UPDATE players SET name = ?, portrait = ?, frame = ?, alliance = ?, power = ?, stage = ?,
			tower = ?, prestige = ?, city = ?, seen = ? WHERE id = ?`),
		rating: db.prepare("UPDATE players SET rating = ? WHERE id = ?"),
		chatAdd: db.prepare("INSERT INTO chat (alliance, player, name, portrait, text, t) VALUES (?, ?, ?, ?, ?, ?)"),
		chatSince: db.prepare(`SELECT id, player, name, portrait, text, t FROM chat
			WHERE alliance = ? AND id > ? AND hidden = 0 ORDER BY id DESC LIMIT 50`),
		chatById: db.prepare("SELECT * FROM chat WHERE id = ?"),
		report: db.prepare("INSERT OR IGNORE INTO reports (message, reporter, t) VALUES (?, ?, ?)"),
		reportCount: db.prepare("SELECT COUNT(*) AS n FROM reports WHERE message = ?"),
		hide: db.prepare("UPDATE chat SET hidden = 1 WHERE id = ?"),
		chatTrim: db.prepare(`DELETE FROM chat WHERE alliance = ? AND id <= (
			SELECT id FROM chat WHERE alliance = ? ORDER BY id DESC LIMIT 1 OFFSET ${CHAT_KEEP})`),
		members: db.prepare("SELECT COUNT(*) AS n, COALESCE(SUM(power), 0) AS power FROM players WHERE alliance = ?"),
		opponents: db.prepare(`SELECT id, name, portrait, frame, power, rating FROM players
			WHERE id != ? AND power > 0 ORDER BY ABS(rating - ?) LIMIT 12`),
		logAdd: db.prepare("INSERT INTO arena_log (attacker, defender, win, delta, t) VALUES (?, ?, ?, ?, ?)"),
		attacksToday: db.prepare("SELECT COUNT(*) AS n FROM arena_log WHERE attacker = ? AND t >= ?"),
		count: db.prepare("SELECT COUNT(*) AS n FROM players"),
		byPrefix: db.prepare("SELECT * FROM players WHERE id LIKE ? LIMIT 2"),
		friendAdd: db.prepare("INSERT OR IGNORE INTO friends (a, b, t) VALUES (?, ?, ?)"),
		friendDel: db.prepare("DELETE FROM friends WHERE (a = ? AND b = ?) OR (a = ? AND b = ?)"),
		friendCount: db.prepare("SELECT COUNT(*) AS n FROM friends WHERE a = ?"),
		friendList: db.prepare(`SELECT p.* FROM friends f JOIN players p ON p.id = f.b WHERE f.a = ? ORDER BY p.power DESC`),
		isFriend: db.prepare("SELECT 1 AS x FROM friends WHERE a = ? AND b = ?"),
		giftAdd: db.prepare("INSERT OR IGNORE INTO gifts (sender, receiver, day) VALUES (?, ?, ?)"),
		giftsSentToday: db.prepare("SELECT receiver FROM gifts WHERE sender = ? AND day = ?"),
		giftsInbox: db.prepare(`SELECT g.id, p.name FROM gifts g JOIN players p ON p.id = g.sender
			WHERE g.receiver = ? AND g.claimed = 0 ORDER BY g.id LIMIT 50`),
		giftsClaimedToday: db.prepare("SELECT COUNT(*) AS n FROM gifts WHERE receiver = ? AND claimed = ?"),
		giftClaim: db.prepare("UPDATE gifts SET claimed = ? WHERE id = ?"),
		king: db.prepare("SELECT * FROM kings WHERE day = ?"),
		kingTop: db.prepare("SELECT * FROM players WHERE power > 0 AND seen >= ? ORDER BY power DESC, created ASC LIMIT 1"),
		kingAdd: db.prepare("INSERT OR IGNORE INTO kings (day, player, name, portrait, frame, power) VALUES (?, ?, ?, ?, ?, ?)"),
		kingDecree: db.prepare("UPDATE kings SET decree = ? WHERE day = ? AND decree IS NULL"),
		gwPoints: db.prepare("SELECT territory, alliance, points FROM guildwar WHERE week = ?"),
		gwAdd: db.prepare(`INSERT INTO guildwar (week, territory, alliance, points) VALUES (?, ?, ?, ?)
			ON CONFLICT (week, territory, alliance) DO UPDATE SET points = points + excluded.points`),
		gwUsed: db.prepare("SELECT n FROM guildwar_attacks WHERE player = ? AND day = ?"),
		bossGet: db.prepare("SELECT * FROM world_boss WHERE week = ?"),
		bossAdd: db.prepare("INSERT OR IGNORE INTO world_boss (week, hp_max) VALUES (?, ?)"),
		bossHit: db.prepare("UPDATE world_boss SET damage = damage + ? WHERE week = ?"),
		bossPower: db.prepare("SELECT COALESCE(SUM(power), 0) AS p FROM players WHERE seen >= ?"),
		hitGet: db.prepare("SELECT * FROM world_boss_hits WHERE week = ? AND player = ?"),
		hitAdd: db.prepare(`INSERT INTO world_boss_hits (week, player, damage, day, n) VALUES (?, ?, ?, ?, 1)
			ON CONFLICT (week, player) DO UPDATE SET damage = damage + excluded.damage,
			n = CASE WHEN day = excluded.day THEN n + 1 ELSE 1 END, day = excluded.day`),
		hitTop: db.prepare(`SELECT h.damage, p.name, p.portrait, p.id FROM world_boss_hits h JOIN players p ON p.id = h.player
			WHERE h.week = ? ORDER BY h.damage DESC LIMIT 10`),
		hitRank: db.prepare("SELECT COUNT(*) AS n FROM world_boss_hits WHERE week = ? AND damage > ?"),
		hitCount: db.prepare("SELECT COUNT(*) AS n FROM world_boss_hits WHERE week = ?"),
		tourneyJoin: db.prepare("INSERT OR REPLACE INTO tourney_entries (week, player, power) VALUES (?, ?, ?)"),
		tourneyEntries: db.prepare(`SELECT e.player AS id, e.power, p.name, p.portrait FROM tourney_entries e
			JOIN players p ON p.id = e.player WHERE e.week = ? ORDER BY e.power DESC, p.created ASC LIMIT ?`),
		tourneyCount: db.prepare("SELECT COUNT(*) AS n FROM tourney_entries WHERE week = ?"),
		tourneyMine: db.prepare("SELECT 1 AS x FROM tourney_entries WHERE week = ? AND player = ?"),
		tourneyGet: db.prepare("SELECT bracket FROM tourney_results WHERE week = ?"),
		tourneySave: db.prepare("INSERT OR IGNORE INTO tourney_results (week, bracket) VALUES (?, ?)"),
		mailList: db.prepare(`SELECT m.*, (SELECT 1 FROM mail_claims c WHERE c.mail = m.id AND c.player = ?) AS claimed
			FROM mail m WHERE (m.target = '*' OR m.target = ?) AND m.expires > ? ORDER BY m.id DESC LIMIT 30`),
		mailGet: db.prepare("SELECT * FROM mail WHERE id = ?"),
		mailClaim: db.prepare("INSERT OR IGNORE INTO mail_claims (mail, player, t) VALUES (?, ?, ?)"),
		statsAdd: db.prepare("INSERT OR REPLACE INTO stats_reports (install, day, payload) VALUES (?, ?, ?)"),
		codeGet: db.prepare("SELECT * FROM codes WHERE code = ?"),
		codeUse: db.prepare("UPDATE codes SET uses = uses + 1 WHERE code = ?"),
		redeemAdd: db.prepare("INSERT OR IGNORE INTO redemptions (code, player, t) VALUES (?, ?, ?)"),
		gwUse: db.prepare(`INSERT INTO guildwar_attacks (player, day, n) VALUES (?, ?, 1)
			ON CONFLICT (player, day) DO UPDATE SET n = n + 1`),
	};

	const dayOf = (t) => Math.floor(t / DAY_MS);
	// Minggu dimulai Senin (1 Jan 1970 = Kamis).
	const weekOf = (t) => Math.floor((dayOf(t) + 3) / 7);
	const friendCode = (p) => p.id.replace(/-/g, "").slice(0, 8).toUpperCase();

	// Raja hari ini: pemain berkekuatan tertinggi yang aktif 3 hari terakhir, dikunci
	// pada permintaan pertama hari itu.
	function todayKing() {
		const day = dayOf(now());
		let k = q.king.get(day);
		if (!k) {
			const top = q.kingTop.get(now() - 3 * DAY_MS);
			if (!top) return null;
			q.kingAdd.run(day, top.id, top.name, top.portrait, top.frame, top.power);
			k = q.king.get(day);
		}
		return k;
	}

	// Bos Dunia minggu `week`: HP = 5x total kekuatan pemain aktif 7 hari terakhir.
	function worldBoss(week) {
		let b = q.bossGet.get(week);
		if (!b) {
			q.bossAdd.run(week, Math.max(BOSS_HP_MIN, q.bossPower.get(now() - 7 * DAY_MS).p * 5));
			b = q.bossGet.get(week);
		}
		return b;
	}

	// Turnamen silat: daftar Senin–Sabtu, hasil dari hari Minggu (dihitung sekali, lalu disimpan).
	const dayInWeek = (t) => (dayOf(t) + 3) % 7;
	function tourneyBracket(week) {
		const saved = q.tourneyGet.get(week);
		if (saved) return JSON.parse(saved.bracket);
		const entries = q.tourneyEntries.all(week, TOURNEY_SIZE);
		if (entries.length < 2) return null;
		let size = 2;
		while (size < entries.length) size *= 2;
		// Unggulan: 1 lawan terakhir, 2 lawan kedua terakhir, dst.; slot kosong = bye.
		const slots = [];
		for (let i = 0; i < size / 2; i++) slots.push(entries[i] || null, entries[size - 1 - i] || null);
		let seed = week * 2654435761 % 4294967296;
		const rnd = () => { seed = (seed * 1664525 + 1013904223) % 4294967296; return seed / 4294967296; };
		const rounds = [];
		let alive = slots;
		while (alive.length > 1) {
			const matches = [];
			const next = [];
			for (let i = 0; i < alive.length; i += 2) {
				const [a, b] = [alive[i], alive[i + 1]];
				let winner = a || b;
				if (a && b) {
					const pa = Math.pow(Math.max(1, a.power), 3);
					const pb = Math.pow(Math.max(1, b.power), 3);
					winner = rnd() < pa / (pa + pb) ? a : b;
				}
				matches.push({ a, b, winner: winner ? winner.id : null });
				next.push(winner);
			}
			rounds.push(matches);
			alive = next;
		}
		const bracket = { rounds, champion: alive[0] ? alive[0].id : null };
		q.tourneySave.run(week, JSON.stringify(bracket));
		return bracket;
	}

	// Jumlah kemenangan pemain di bagan; -1 bila tidak ikut. Juara = jumlah babak.
	function tourneyWins(bracket, id) {
		if (!bracket) return -1;
		let wins = -1;
		for (const round of bracket.rounds) {
			for (const m of round) {
				if ((m.a && m.a.id === id) || (m.b && m.b.id === id)) wins = Math.max(wins, 0) + (m.winner === id ? 1 : 0);
			}
		}
		return wins;
	}

	function bossStanding(week, me) {
		const hit = q.hitGet.get(week, me.id);
		return { damage: hit ? hit.damage : 0, rank: hit ? q.hitRank.get(week, hit.damage).n + 1 : 0,
			players: q.hitCount.get(week).n };
	}

	// Pemilik tiap wilayah pada minggu `week`: aliansi dengan poin terbanyak.
	function guildwarBoard(week) {
		const rows = q.gwPoints.all(week);
		return TERRITORIES.map((name, i) => {
			const points = {};
			for (const r of rows) if (r.territory === i) points[r.alliance] = r.points;
			let owner = null;
			for (const a of ALLIANCES) if ((points[a] || 0) > (owner ? points[owner] : 0)) owner = a;
			return { id: i, name, owner, points };
		});
	}

	function publicPlayer(p) {
		return { id: p.id, name: p.name, portrait: p.portrait, frame: p.frame, alliance: p.alliance,
			power: p.power, stage: p.stage, tower: p.tower, prestige: p.prestige, rating: p.rating, code: friendCode(p) };
	}

	// Ringkasan kota untuk kunjungan: hanya angka kecil yang aman ditampilkan.
	function cleanCity(raw) {
		const c = raw && typeof raw === "object" ? raw : {};
		const out = { rank: clampInt(c.rank, 0, 20), buildings: {}, kin: clampInt(c.kin, 0, 999),
			ships: clampInt(c.ships, 0, 10), regions: clampInt(c.regions, 0, 100), counselors: clampInt(c.counselors, 0, 999) };
		for (const k of ["istana", "pasar", "lumbung", "barak"]) out.buildings[k] = clampInt(c.buildings?.[k], 0, 99);
		out.badges = Array.isArray(c.badges) ? [...new Set(c.badges.filter((b) => BADGE_IDS.includes(b)))] : [];
		return JSON.stringify(out);
	}

	function leaderboard(cat, me, limit) {
		const top = db.prepare(`SELECT * FROM players WHERE ${cat} > 0 ORDER BY ${cat} DESC, created ASC LIMIT ?`)
			.all(limit).map((p, i) => ({ rank: i + 1, value: p[cat], ...publicPlayer(p) }));
		const mine = db.prepare(`SELECT COUNT(*) AS n FROM players WHERE ${cat} > ?`).get(me[cat]).n + 1;
		return { category: cat, top, me: { rank: mine, value: me[cat] }, players: q.count.get().n };
	}

	const routes = {
		"GET /health": () => [200, { ok: true, players: q.count.get().n }],

		"POST /v1/auth/device": (_me, body) => {
			const device = String(body.device_id || "");
			if (device.length < 16) return [400, { error: "device_id minimal 16 karakter" }];
			const hash = crypto.createHash("sha256").update(device).digest("hex");
			let p = q.byDevice.get(hash);
			if (!p) {
				const id = crypto.randomUUID();
				q.insert.run(id, hash, crypto.randomBytes(24).toString("hex"), cleanName(body.name), now(), now());
				p = q.byId.get(id);
			}
			return [200, { player: publicPlayer(p), token: p.token }];
		},

		// (auth) Laporan profil berkala dari klien: dipakai peringkat, aliansi, dan arena.
		"POST /v1/profile": (me, body) => {
			const alliance = ALLIANCES.includes(body.alliance) ? body.alliance : null;
			q.profile.run(cleanName(body.name ?? me.name), String(body.portrait || me.portrait).slice(0, 32),
				String(body.frame || me.frame).slice(0, 32), alliance, clampInt(body.power, 0, 1e15),
				clampInt(body.stage, 0, 1e6), clampInt(body.tower, 0, 1e6), clampInt(body.prestige, 0, 1e12),
				cleanCity(body.city), now(), me.id);
			return [200, { player: publicPlayer(q.byId.get(me.id)) }];
		},

		// (auth) ?cat=power|stage|tower|prestige&limit=50
		"GET /v1/leaderboard": (me, _body, params) => {
			const cat = LEADERBOARDS.includes(params.get("cat")) ? params.get("cat") : "power";
			return [200, leaderboard(cat, me, clampInt(params.get("limit") || 50, 1, 100))];
		},

		"GET /v1/alliances": () => [200, { alliances: ALLIANCES.map((id) => {
			const m = q.members.get(id);
			return { id, members: m.n, power: m.power };
		}) }],

		// (auth) ?after=<id pesan terakhir yang sudah dimiliki>
		"GET /v1/chat": (me, _body, params) => {
			if (!me.alliance) return [200, { messages: [] }];
			const after = clampInt(params.get("after") || 0, 0, Number.MAX_SAFE_INTEGER);
			const messages = q.chatSince.all(me.alliance, after).reverse()
				.map((m) => ({ ...m, me: m.player === me.id }));
			return [200, { alliance: me.alliance, messages }];
		},

		"POST /v1/chat": (me, body) => {
			if (!me.alliance) return [400, { error: "Belum bergabung dengan aliansi." }];
			const text = filterText(String(body.text || "").replace(/[\u0000-\u001f]/g, " ").trim().slice(0, CHAT_MAX));
			if (!text) return [400, { error: "Pesan kosong." }];
			if (now() - (lastChat.get(me.id) || 0) < CHAT_COOLDOWN_MS) return [429, { error: "Tunggu sebentar." }];
			lastChat.set(me.id, now());
			const r = q.chatAdd.run(me.alliance, me.id, me.name, me.portrait, text, now());
			q.chatTrim.run(me.alliance, me.alliance);
			return [200, { id: Number(r.lastInsertRowid) }];
		},

		// (auth) Laporkan pesan; pesan disembunyikan setelah REPORT_HIDE laporan berbeda.
		// Laporan tersimpan di tabel reports untuk ditinjau pengelola server.
		"POST /v1/chat/report": (me, body) => {
			const msg = q.chatById.get(clampInt(body.message_id, 0, Number.MAX_SAFE_INTEGER));
			if (!msg || msg.alliance !== me.alliance) return [404, { error: "Pesan tidak ditemukan." }];
			if (msg.player === me.id) return [400, { error: "Tidak bisa melaporkan pesan sendiri." }];
			q.report.run(msg.id, me.id, now());
			const hidden = q.reportCount.get(msg.id).n >= REPORT_HIDE;
			if (hidden) q.hide.run(msg.id);
			return [200, { reported: true, hidden }];
		},

		// (auth) Tiga lawan sungguhan dengan poin arena terdekat.
		"GET /v1/arena/opponents": (me) => {
			const pool = q.opponents.all(me.id, me.rating);
			for (let i = pool.length - 1; i > 0; i--) {
				const j = Math.floor(random() * (i + 1));
				[pool[i], pool[j]] = [pool[j], pool[i]];
			}
			return [200, { rating: me.rating, opponents: pool.slice(0, 3).map((p) => ({ ...p, code: friendCode(p) })) }];
		},

		// (auth) Server menentukan menang/kalah dari kekuatan tersimpan dan mengubah
		// poin kedua pemain (Elo). Maks. 20 serangan per 24 jam.
		"POST /v1/arena/fight": (me, body) => {
			const opp = q.byId.get(String(body.opponent_id || ""));
			if (!opp || opp.id === me.id) return [404, { error: "Lawan tidak ditemukan." }];
			if (q.attacksToday.get(me.id, now() - 86400000).n >= 20) return [429, { error: "Batas serangan harian." }];
			const a = Math.pow(Math.max(1, me.power), 3);
			const b = Math.pow(Math.max(1, opp.power), 3);
			const win = random() < a / (a + b);
			const expected = 1 / (1 + Math.pow(10, (opp.rating - me.rating) / 400));
			const delta = Math.round(ARENA_K * ((win ? 1 : 0) - expected));
			q.rating.run(Math.max(0, me.rating + delta), me.id);
			q.rating.run(Math.max(0, opp.rating - delta), opp.id);
			q.logAdd.run(me.id, opp.id, win ? 1 : 0, delta, now());
			return [200, { win, delta, rating: Math.max(0, me.rating + delta), opponent: publicPlayer(opp) }];
		},
	};

	Object.assign(routes, {
		// (auth) Daftar teman, hadiah yang sudah dikirim hari ini, dan kotak masuk hadiah.
		"GET /v1/friends": (me) => {
			const sent = new Set(q.giftsSentToday.all(me.id, dayOf(now())).map((r) => r.receiver));
			const friends = q.friendList.all(me.id).map((p) => ({ ...publicPlayer(p), gift_sent: sent.has(p.id) }));
			return [200, { code: friendCode(me), friends, inbox: q.giftsInbox.all(me.id) }];
		},

		// (auth) Tambah teman dengan kode 8 karakter; pertemanan berlaku dua arah.
		"POST /v1/friends/add": (me, body) => {
			const code = String(body.code || "").replace(/[^0-9a-f]/gi, "").toLowerCase();
			if (code.length !== 8) return [400, { error: "Kode teman harus 8 karakter." }];
			const found = q.byPrefix.all(code + "%").filter((p) => p.id.replace(/-/g, "").startsWith(code));
			if (found.length !== 1) return [404, { error: "Pemain tidak ditemukan." }];
			const other = found[0];
			if (other.id === me.id) return [400, { error: "Itu kode Tuan sendiri." }];
			if (q.friendCount.get(me.id).n >= FRIENDS_MAX) return [400, { error: "Daftar teman penuh." }];
			q.friendAdd.run(me.id, other.id, now());
			q.friendAdd.run(other.id, me.id, now());
			return [200, { friend: publicPlayer(other) }];
		},

		"POST /v1/friends/remove": (me, body) => {
			const id = String(body.id || "");
			q.friendDel.run(me.id, id, id, me.id);
			return [200, { removed: true }];
		},

		// (auth) Kirim satu hadiah per teman per hari.
		"POST /v1/gift": (me, body) => {
			const to = String(body.to || "");
			if (!q.isFriend.get(me.id, to)) return [404, { error: "Bukan teman Tuan." }];
			const r = q.giftAdd.run(me.id, to, dayOf(now()));
			if (r.changes === 0) return [429, { error: "Hadiah untuk teman ini sudah dikirim hari ini." }];
			return [200, { sent: true }];
		},

		// (auth) Ambil hadiah dari kotak masuk, maks. GIFT_CLAIM_DAILY per hari.
		"POST /v1/gifts/claim": (me) => {
			const stamp = dayOf(now()) + 1; // kolom claimed menyimpan hari klaim + 1
			const left = GIFT_CLAIM_DAILY - q.giftsClaimedToday.get(me.id, stamp).n;
			const take = q.giftsInbox.all(me.id).slice(0, Math.max(0, left));
			for (const g of take) q.giftClaim.run(stamp, g.id);
			return [200, { claimed: take.length, names: take.map((g) => g.name) }];
		},

		// (auth) Kunjungi kota pemain lain (?id=).
		"GET /v1/player": (me, _body, params) => {
			const p = q.byId.get(String(params.get("id") || ""));
			if (!p) return [404, { error: "Pemain tidak ditemukan." }];
			let city = {};
			try {
				city = JSON.parse(p.city || "{}");
			} catch {
				city = {};
			}
			return [200, { player: publicPlayer(p), city, friend: !!q.isFriend.get(me.id, p.id) }];
		},

		// (auth) Raja Hari Ini dan titahnya.
		"GET /v1/king": (me) => {
			const k = todayKing();
			if (!k) return [200, { king: null }];
			return [200, { king: { id: k.player, name: k.name, portrait: k.portrait, frame: k.frame, power: k.power },
				decree: k.decree, me: k.player === me.id, decrees: DECREES }];
		},

		// (auth) Hanya raja hari ini; titah dipilih sekali dari daftar tetap (tanpa teks bebas).
		"POST /v1/king/decree": (me, body) => {
			const k = todayKing();
			if (!k || k.player !== me.id) return [403, { error: "Hanya Raja Hari Ini yang bisa bertitah." }];
			const decree = String(body.decree || "");
			if (!DECREES.includes(decree)) return [400, { error: "Titah tidak dikenal." }];
			if (k.decree) return [400, { error: "Titah hari ini sudah ditetapkan." }];
			q.kingDecree.run(decree, dayOf(now()));
			return [200, { decree }];
		},

		// (auth) Papan Perang Wilayah minggu ini, hasil minggu lalu, dan sisa serangan.
		"GET /v1/guildwar": (me) => {
			const week = weekOf(now());
			const used = q.gwUsed.get(me.id, dayOf(now()))?.n || 0;
			const last = guildwarBoard(week - 1);
			return [200, { week, territories: guildwarBoard(week), attacks_left: Math.max(0, GUILDWAR_ATTACKS - used),
				alliance: me.alliance, last_week: week - 1,
				last_won: me.alliance ? last.filter((t) => t.owner === me.alliance).length : 0,
				ends_in: (week + 1) * 7 * DAY_MS - 3 * DAY_MS - now() }];
		},

		// (auth) Serang wilayah: poin = akar kekuatan x acak 0,8–1,2.
		"POST /v1/guildwar/attack": (me, body) => {
			if (!me.alliance) return [400, { error: "Bergabunglah dengan aliansi dulu." }];
			const t = clampInt(body.territory, -1, TERRITORIES.length);
			if (t < 0 || t >= TERRITORIES.length) return [404, { error: "Wilayah tidak ditemukan." }];
			const day = dayOf(now());
			if ((q.gwUsed.get(me.id, day)?.n || 0) >= GUILDWAR_ATTACKS) return [429, { error: "Serangan hari ini habis." }];
			const points = Math.max(1, Math.round(Math.sqrt(Math.max(1, me.power)) * (0.8 + 0.4 * random())));
			q.gwUse.run(me.id, day);
			q.gwAdd.run(weekOf(now()), t, me.alliance, points);
			return [200, { points, territory: guildwarBoard(weekOf(now()))[t] }];
		},
	});

	Object.assign(routes, {
		// (auth) Bos Dunia minggu ini, peringkat Tuan, dan hasil minggu lalu (untuk hadiah).
		"GET /v1/worldboss": (me) => {
			const week = weekOf(now());
			const boss = worldBoss(week);
			const hit = q.hitGet.get(week, me.id);
			const used = hit && hit.day === dayOf(now()) ? hit.n : 0;
			const last = q.bossGet.get(week - 1);
			return [200, { week, hp_max: boss.hp_max, damage: boss.damage, defeated: boss.damage >= boss.hp_max,
				attacks_left: Math.max(0, BOSS_ATTACKS - used), me: bossStanding(week, me), top: q.hitTop.all(week),
				last_week: week - 1, last: { ...bossStanding(week - 1, me), defeated: !!last && last.damage >= last.hp_max },
				ends_in: (week + 1) * 7 * DAY_MS - 3 * DAY_MS - now() }];
		},

		// (auth) Serang bos: kerusakan = kekuatan x acak 0,8–1,2. Maks. 3 kali sehari.
		"POST /v1/worldboss/attack": (me) => {
			const week = weekOf(now());
			const boss = worldBoss(week);
			const hit = q.hitGet.get(week, me.id);
			if (hit && hit.day === dayOf(now()) && hit.n >= BOSS_ATTACKS) return [429, { error: "Serangan hari ini habis." }];
			const damage = Math.max(1, Math.round(Math.max(1, me.power) * (0.8 + 0.4 * random())));
			q.hitAdd.run(week, me.id, damage, dayOf(now()));
			q.bossHit.run(damage, week);
			const b = q.bossGet.get(week);
			return [200, { damage, hp_max: b.hp_max, total: b.damage, defeated: b.damage >= b.hp_max,
				hp_before: Math.max(0, b.hp_max - b.damage + damage) }];
		},

		// (auth) Turnamen silat minggu ini dan hasil minggu lalu.
		"GET /v1/tourney": (me) => {
			const week = weekOf(now());
			const done = dayInWeek(now()) === 6;
			const bracket = done ? tourneyBracket(week) : null;
			const last = tourneyBracket(week - 1);
			return [200, { week, phase: done ? "done" : "register", registered: !!q.tourneyMine.get(week, me.id),
				count: q.tourneyCount.get(week).n, entrants: q.tourneyEntries.all(week, TOURNEY_SIZE).map((e) => e.name),
				bracket, my_wins: tourneyWins(bracket, me.id), rounds: bracket ? bracket.rounds.length : 0,
				last_week: week - 1, last_wins: tourneyWins(last, me.id), last_rounds: last ? last.rounds.length : 0 }];
		},

		// (auth) Daftar turnamen (Senin–Sabtu) dengan kekuatan saat ini.
		"POST /v1/tourney/join": (me) => {
			if (dayInWeek(now()) === 6) return [400, { error: "Pendaftaran sudah ditutup. Hasil diumumkan hari ini." }];
			if (me.power <= 0) return [400, { error: "Kirim profil dulu." }];
			q.tourneyJoin.run(weekOf(now()), me.id, me.power);
			return [200, { registered: true, count: q.tourneyCount.get(weekOf(now())).n }];
		},

		// (auth) Kotak surat: surat untuk semua pemain ("*") atau untuk Tuan saja.
		"GET /v1/mail": (me) => [200, { mail: q.mailList.all(me.id, me.id, now()).map((m) => ({ id: m.id, title: m.title,
			body: m.body, reward: JSON.parse(m.reward), created: m.created, expires: m.expires, claimed: !!m.claimed })) }],

		"POST /v1/mail/claim": (me, body) => {
			const m = q.mailGet.get(clampInt(body.id, 0, Number.MAX_SAFE_INTEGER));
			if (!m || (m.target !== "*" && m.target !== me.id) || m.expires <= now()) return [404, { error: "Surat tidak ditemukan." }];
			if (q.mailClaim.run(m.id, me.id, now()).changes === 0) return [409, { error: "Hadiah surat ini sudah diambil." }];
			return [200, { id: m.id, reward: cleanReward(JSON.parse(m.reward)) }];
		},

		// Statistik anonim (opt-in di game): satu laporan ringkas per pemasangan per hari.
		// Tidak memakai token akun; "install" adalah ID acak terpisah dari akun.
		"POST /v1/stats": (_me, body) => {
			const install = String(body.install || "").replace(/[^0-9a-f]/gi, "").slice(0, 32);
			if (install.length < 16) return [400, { error: "install tidak valid" }];
			const clean = cleanStats(body);
			q.statsAdd.run(install, dayOf(now()), JSON.stringify(clean));
			return [200, { ok: true }];
		},

		// (auth) Tukar kode hadiah buatan pengelola (lihat server/admin.js).
		"POST /v1/redeem": (me, body) => {
			const code = String(body.code || "").toUpperCase().replace(/\s/g, "").slice(0, 32);
			const c = code ? q.codeGet.get(code) : null;
			if (!c || c.expires < now()) return [404, { error: "Kode tidak dikenal atau sudah kedaluwarsa." }];
			if (c.uses >= c.max_uses) return [410, { error: "Kuota kode ini sudah habis." }];
			if (q.redeemAdd.run(code, me.id, now()).changes === 0) return [409, { error: "Kode ini sudah Tuan pakai." }];
			q.codeUse.run(code);
			return [200, { code, reward: cleanReward(JSON.parse(c.reward)) }];
		},
	});

	const open = new Set(["GET /health", "POST /v1/auth/device", "GET /v1/alliances", "POST /v1/stats"]);
	require("./batch8.js").install({ db, routes, open, now, random, opts, h: { dayOf, weekOf, friendCode, addMail,
		cleanReward, clampInt, addCode, statsSummary, ALLIANCES, CODE_ITEMS } });

	const handler = async (req, res) => {
		const url = new URL(req.url, "http://x");
		const key = `${req.method} ${url.pathname}`;
		const send = (code, data, type) => {
			res.writeHead(code, { "Content-Type": type || "application/json; charset=utf-8", "Access-Control-Allow-Origin": "*" });
			res.end(type ? data : JSON.stringify(data));
		};
		const route = routes[key];
		if (!route) return send(404, { error: "Tidak ditemukan." });
		let body = {};
		if (req.method === "POST") {
			let raw = "";
			for await (const chunk of req) {
				raw += chunk;
				if (raw.length > 16384) return send(413, { error: "Terlalu besar." });
			}
			try {
				body = raw ? JSON.parse(raw) : {};
			} catch {
				return send(400, { error: "JSON tidak valid." });
			}
		}
		let me = null;
		if (!open.has(key)) {
			const token = (req.headers.authorization || "").replace(/^Bearer\s+/i, "");
			me = token ? q.byToken.get(token) : null;
			if (!me) return send(401, { error: "Token tidak valid." });
			q.seen.run(now(), me.id);
		}
		try {
			const [code, data, type] = await route(me, body, url.searchParams, req);
			send(code, data, type);
		} catch (e) {
			console.error(e);
			send(500, { error: "Kesalahan server." });
		}
	};
	const server = http.createServer(handler);
	server.db = db;
	return server;
}

// Tambah/ubah kode hadiah langsung di database (dipakai server/admin.js dan tes).
function addCode(db, code, reward, maxUses, expires) {
	db.prepare(`INSERT INTO codes (code, reward, max_uses, expires) VALUES (?, ?, ?, ?)
		ON CONFLICT (code) DO UPDATE SET reward = excluded.reward, max_uses = excluded.max_uses, expires = excluded.expires`)
		.run(String(code).toUpperCase(), JSON.stringify(cleanReward(reward)), maxUses, expires);
}

// Ringkasan statistik anonim per hari, retensi H1/H7, dan aksi teratas (admin.js stats & dasbor).
function statsSummary(db, days, nowMs = Date.now()) {
	const today = Math.floor(nowMs / 86400000);
	const rows = db.prepare("SELECT install, day, payload FROM stats_reports WHERE day > ?").all(today - days - 30);
	const first = {};
	for (const r of db.prepare("SELECT install, MIN(day) AS d FROM stats_reports GROUP BY install").all()) first[r.install] = r.d;
	const byDay = {};
	for (const r of rows) (byDay[r.day] ||= []).push({ install: r.install, ...JSON.parse(r.payload) });
	const out = { days: [], retention: {}, events: [] };
	for (let d = today - days + 1; d <= today; d++) {
		const list = byDay[d] || [];
		const stages = list.map((x) => x.stage).sort((a, b) => a - b);
		const avg = (f) => (list.length ? list.reduce((s, x) => s + f(x), 0) / list.length : 0);
		out.days.push({ date: new Date(d * 86400000).toISOString().slice(0, 10), active: list.length,
			new: list.filter((x) => first[x.install] === d).length, sessions: +avg((x) => x.sessions).toFixed(1),
			minutes: Math.round(avg((x) => x.play_seconds) / 60), median_stage: stages[Math.floor(stages.length / 2)] || 0,
			tutorial: Math.round(avg((x) => (x.tutorial_done ? 1 : 0)) * 100) });
	}
	const cohort = Object.entries(first).filter(([, d]) => d > today - days && d <= today - 7);
	const seen = new Set(rows.map((r) => `${r.install}:${r.day}`));
	const ret = (k) => (cohort.length ? Math.round(cohort.filter(([i, d]) => seen.has(`${i}:${d + k}`)).length / cohort.length * 100) : 0);
	out.retention = { cohort: cohort.length, d1: ret(1), d7: ret(7) };
	const events = {};
	for (const list of Object.values(byDay)) {
		for (const x of list) for (const [k, v] of Object.entries(x.events || {})) events[k] = (events[k] || 0) + v;
	}
	out.events = Object.entries(events).sort((a, b) => b[1] - a[1]).slice(0, 15);
	return out;
}

module.exports = { createServer, openDb, addCode, cleanReward, addMail, statsSummary };

if (require.main === module) {
	const port = Number(process.env.PORT || 8080);
	const dbPath = process.env.DB_PATH || path.join(__dirname, "data", "tlg.db");
	createServer({ dbPath }).listen(port, () => console.log(`Server TLG di port ${port}, data: ${dbPath}`));
}
