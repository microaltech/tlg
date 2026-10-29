// Server sosial Top Lord Like: akun perangkat, profil pemain, papan peringkat,
// chat aliansi, dan arena melawan pemain sungguhan.
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
	`);
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
			tower = ?, prestige = ?, seen = ? WHERE id = ?`),
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
	};

	function publicPlayer(p) {
		return { id: p.id, name: p.name, portrait: p.portrait, frame: p.frame, alliance: p.alliance,
			power: p.power, stage: p.stage, tower: p.tower, prestige: p.prestige, rating: p.rating };
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
				clampInt(body.stage, 0, 1e6), clampInt(body.tower, 0, 1e6), clampInt(body.prestige, 0, 1e12), now(), me.id);
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
			return [200, { rating: me.rating, opponents: pool.slice(0, 3) }];
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

	const handler = async (req, res) => {
		const url = new URL(req.url, "http://x");
		const key = `${req.method} ${url.pathname}`;
		const send = (code, data) => {
			res.writeHead(code, { "Content-Type": "application/json; charset=utf-8", "Access-Control-Allow-Origin": "*" });
			res.end(JSON.stringify(data));
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
		const open = key === "GET /health" || key === "POST /v1/auth/device" || key === "GET /v1/alliances";
		if (!open) {
			const token = (req.headers.authorization || "").replace(/^Bearer\s+/i, "");
			me = token ? q.byToken.get(token) : null;
			if (!me) return send(401, { error: "Token tidak valid." });
			q.seen.run(now(), me.id);
		}
		try {
			const [code, data] = route(me, body, url.searchParams);
			send(code, data);
		} catch (e) {
			console.error(e);
			send(500, { error: "Kesalahan server." });
		}
	};
	const server = http.createServer(handler);
	server.db = db;
	return server;
}

module.exports = { createServer };

if (require.main === module) {
	const port = Number(process.env.PORT || 8080);
	const dbPath = process.env.DB_PATH || path.join(__dirname, "data", "tlg.db");
	createServer({ dbPath }).listen(port, () => console.log(`Server TLG di port ${port}, data: ${dbPath}`));
}
