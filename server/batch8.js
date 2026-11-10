"use strict";
// Fitur server tambahan:
// - Undang teman: kode undangan = kode teman; hadiah untuk keduanya saat yang diundang mencapai tahap 10.
// - Musim aliansi: liga 4 minggu dari poin Perang Wilayah dan Bos Dunia, hadiah untuk 3 aliansi teratas.
// - Pasar antar pemain: jual item dengan perak, batas harian, pajak 10%, hasil penjualan lewat kotak surat.
// - Pemberitahuan: ringkasan yang dibaca pekerja latar Android (surat, bos, turnamen, dagangan laku).
// - Dasbor admin web di /admin (butuh ADMIN_TOKEN).
// - Verifikasi pembelian Google Play (purchases.products.get) sebelum emas diberikan.

const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

const REFERRAL_STAGE = 10;
const REFERRAL_MAX = 20; // undangan berhadiah per pengundang
const REFERRAL_REWARD = { gold: 100, items: { recruit_ticket: 2 } };
const SEASON_WEEKS = 4;
const SEASON_START = Date.UTC(2026, 0, 5); // Senin pertama 2026
const SEASON_REWARDS = [
	{ gold: 300, items: { star_stone: 2 }, frame: "frame_juara_musim" },
	{ gold: 200, items: { star_stone: 1 }, frame: "frame_musim" },
	{ gold: 100, items: { recruit_ticket: 1 }, frame: "frame_musim" },
];
const MARKET_DAILY = 5;
const MARKET_TAX = 0.1;
const MARKET_DAYS = 3;
const MARKET_PRICE_MAX = 10000000;
const MARKET_QTY_MAX = 10;

function install(ctx) {
	const { db, routes, open, now, h } = ctx;
	const DAY = 86400000;
	db.exec(`
		CREATE TABLE IF NOT EXISTS referrals (invitee TEXT PRIMARY KEY, inviter TEXT NOT NULL, t INTEGER NOT NULL,
			rewarded INTEGER NOT NULL DEFAULT 0);
		CREATE TABLE IF NOT EXISTS season_points (season INTEGER NOT NULL, alliance TEXT NOT NULL, points INTEGER NOT NULL,
			PRIMARY KEY (season, alliance));
		CREATE TABLE IF NOT EXISTS season_claims (season INTEGER NOT NULL, player TEXT NOT NULL, PRIMARY KEY (season, player));
		CREATE TABLE IF NOT EXISTS market (id INTEGER PRIMARY KEY AUTOINCREMENT, seller TEXT NOT NULL, seller_name TEXT NOT NULL,
			item TEXT NOT NULL, qty INTEGER NOT NULL, price INTEGER NOT NULL, created INTEGER NOT NULL,
			status TEXT NOT NULL DEFAULT 'open', buyer TEXT, closed INTEGER);
		CREATE INDEX IF NOT EXISTS market_open ON market (status, created);
		CREATE TABLE IF NOT EXISTS iap_tokens (token TEXT PRIMARY KEY, player TEXT NOT NULL, product TEXT NOT NULL,
			t INTEGER NOT NULL);
	`);
	const q = {
		refGet: db.prepare("SELECT * FROM referrals WHERE invitee = ?"),
		refAdd: db.prepare("INSERT OR IGNORE INTO referrals (invitee, inviter, t) VALUES (?, ?, ?)"),
		refCount: db.prepare("SELECT COUNT(*) AS n, COALESCE(SUM(rewarded), 0) AS done FROM referrals WHERE inviter = ?"),
		refDone: db.prepare("UPDATE referrals SET rewarded = 1 WHERE invitee = ? AND rewarded = 0"),
		byId: db.prepare("SELECT * FROM players WHERE id = ?"),
		byPrefix: db.prepare("SELECT * FROM players WHERE id LIKE ? LIMIT 2"),
		seasonAdd: db.prepare(`INSERT INTO season_points (season, alliance, points) VALUES (?, ?, ?)
			ON CONFLICT (season, alliance) DO UPDATE SET points = points + excluded.points`),
		seasonBoard: db.prepare("SELECT alliance, points FROM season_points WHERE season = ? ORDER BY points DESC, alliance"),
		seasonClaim: db.prepare("INSERT OR IGNORE INTO season_claims (season, player) VALUES (?, ?)"),
		seasonClaimed: db.prepare("SELECT 1 AS x FROM season_claims WHERE season = ? AND player = ?"),
		mkAdd: db.prepare(`INSERT INTO market (seller, seller_name, item, qty, price, created) VALUES (?, ?, ?, ?, ?, ?)`),
		mkToday: db.prepare("SELECT COUNT(*) AS n FROM market WHERE seller = ? AND created >= ?"),
		mkList: db.prepare(`SELECT id, seller, seller_name, item, qty, price, created FROM market
			WHERE status = 'open' AND created > ? ORDER BY created DESC LIMIT 60`),
		mkMine: db.prepare(`SELECT id, item, qty, price, created, status FROM market WHERE seller = ?
			ORDER BY id DESC LIMIT 20`),
		mkGet: db.prepare("SELECT * FROM market WHERE id = ?"),
		mkClose: db.prepare("UPDATE market SET status = ?, buyer = ?, closed = ? WHERE id = ? AND status = 'open'"),
		mkExpired: db.prepare("SELECT * FROM market WHERE status = 'open' AND created <= ?"),
		mkSoldSince: db.prepare("SELECT COUNT(*) AS n FROM market WHERE seller = ? AND status = 'sold' AND closed > ?"),
		iapUsed: db.prepare("SELECT * FROM iap_tokens WHERE token = ?"),
		iapAdd: db.prepare("INSERT INTO iap_tokens (token, player, product, t) VALUES (?, ?, ?, ?)"),
	};

	const seasonOf = (t) => Math.floor(h.weekOf(t) / SEASON_WEEKS);
	// Nomor musim untuk ditampilkan: musim pertama = musim yang berjalan pada SEASON_START.
	const seasonNumber = (s) => Math.max(1, s - seasonOf(SEASON_START) + 1);
	const findByCode = (raw) => {
		const code = String(raw || "").replace(/[^0-9a-f]/gi, "").toLowerCase();
		if (code.length !== 8) return null;
		const found = q.byPrefix.all(code + "%").filter((p) => p.id.replace(/-/g, "").startsWith(code));
		return found.length === 1 ? found[0] : null;
	};

	// --- Undang teman ---------------------------------------------------------------
	// Hadiah diberikan lewat kotak surat begitu profil yang diundang melaporkan tahap >= 10.
	function checkReferral(player) {
		const r = q.refGet.get(player.id);
		if (!r || r.rewarded || player.stage < REFERRAL_STAGE) return;
		if (q.refDone.run(player.id).changes === 0) return;
		const inviter = q.byId.get(r.inviter);
		if (inviter && q.refCount.get(inviter.id).done <= REFERRAL_MAX) {
			h.addMail(db, inviter.id, "Undangan Berhasil", `${player.name} yang Tuan undang mencapai Tahap ${REFERRAL_STAGE}.`,
				REFERRAL_REWARD, 30, now());
		}
		h.addMail(db, player.id, "Hadiah Undangan", `Terima kasih telah bergabung lewat undangan ${inviter ? inviter.name : "teman"}.`,
			REFERRAL_REWARD, 30, now());
	}

	const profile = routes["POST /v1/profile"];
	routes["POST /v1/profile"] = (me, body) => {
		const res = profile(me, body);
		if (res[0] === 200) checkReferral(q.byId.get(me.id));
		return res;
	};

	routes["GET /v1/referral"] = (me) => {
		const r = q.refGet.get(me.id);
		const c = q.refCount.get(me.id);
		const inviter = r ? q.byId.get(r.inviter) : null;
		return [200, { code: h.friendCode(me), invited: c.n, rewarded: c.done, stage_needed: REFERRAL_STAGE,
			reward: REFERRAL_REWARD, inviter: inviter ? inviter.name : null, inviter_rewarded: r ? !!r.rewarded : false }];
	};

	// Masukkan kode pengundang: sekali per akun, hanya untuk akun berumur < 7 hari.
	routes["POST /v1/referral"] = (me, body) => {
		if (q.refGet.get(me.id)) return [409, { error: "Kode undangan sudah dimasukkan." }];
		if (now() - me.created > 7 * DAY) return [400, { error: "Kode undangan hanya untuk pemain baru (7 hari pertama)." }];
		const inviter = findByCode(body.code);
		if (!inviter) return [404, { error: "Kode undangan tidak ditemukan." }];
		if (inviter.id === me.id) return [400, { error: "Itu kode Tuan sendiri." }];
		if (inviter.created > me.created) return [400, { error: "Pengundang harus bermain lebih dulu dari Tuan." }];
		q.refAdd.run(me.id, inviter.id, now());
		checkReferral(me);
		return [200, { inviter: inviter.name, stage_needed: REFERRAL_STAGE }];
	};

	// --- Musim aliansi ----------------------------------------------------------------
	const gwAttack = routes["POST /v1/guildwar/attack"];
	routes["POST /v1/guildwar/attack"] = (me, body) => {
		const res = gwAttack(me, body);
		if (res[0] === 200 && me.alliance) q.seasonAdd.run(seasonOf(now()), me.alliance, res[1].points);
		return res;
	};
	const bossAttack = routes["POST /v1/worldboss/attack"];
	routes["POST /v1/worldboss/attack"] = (me, body) => {
		const res = bossAttack(me, body);
		if (res[0] === 200 && me.alliance) {
			q.seasonAdd.run(seasonOf(now()), me.alliance, Math.max(1, Math.round(Math.sqrt(res[1].damage))));
		}
		return res;
	};

	function seasonBoard(season) {
		const pts = {};
		for (const r of q.seasonBoard.all(season)) pts[r.alliance] = r.points;
		return h.ALLIANCES.map((a) => ({ alliance: a, points: pts[a] || 0 }))
			.sort((x, y) => y.points - x.points || x.alliance.localeCompare(y.alliance))
			.map((r, i) => ({ ...r, rank: r.points > 0 ? i + 1 : 0 }));
	}

	routes["GET /v1/season"] = (me) => {
		const season = seasonOf(now());
		const last = seasonBoard(season - 1);
		const mine = last.find((r) => r.alliance === me.alliance);
		const lastRank = mine ? mine.rank : 0;
		return [200, { season, number: seasonNumber(season), weeks: SEASON_WEEKS, board: seasonBoard(season),
			ends_in: (season + 1) * SEASON_WEEKS * 7 * DAY - 3 * DAY - now(), last_board: last, last_rank: lastRank,
			last_reward: lastRank >= 1 && lastRank <= 3 ? SEASON_REWARDS[lastRank - 1] : null,
			last_claimed: !!q.seasonClaimed.get(season - 1, me.id) }];
	};

	// Hadiah musim lalu untuk anggota aliansi peringkat 1–3 (keanggotaan saat klaim).
	routes["POST /v1/season/claim"] = (me) => {
		const season = seasonOf(now()) - 1;
		const row = seasonBoard(season).find((r) => r.alliance === me.alliance);
		if (!row || row.rank < 1 || row.rank > 3) return [400, { error: "Aliansi Tuan tidak masuk 3 besar musim lalu." }];
		if (q.seasonClaim.run(season, me.id).changes === 0) return [409, { error: "Hadiah musim ini sudah diambil." }];
		const r = SEASON_REWARDS[row.rank - 1];
		return [200, { season, rank: row.rank, reward: h.cleanReward(r), frame: r.frame }];
	};

	// --- Pasar antar pemain -----------------------------------------------------------
	// Item dipotong di perangkat penjual saat menaruh dagangan; perak hasil penjualan
	// (dikurangi pajak) dan dagangan yang batal/kedaluwarsa dikembalikan lewat kotak surat.
	function sweepMarket() {
		for (const m of q.mkExpired.all(now() - MARKET_DAYS * DAY)) {
			if (q.mkClose.run("expired", null, now(), m.id).changes) {
				h.addMail(db, m.seller, "Dagangan Kembali", "Dagangan Tuan tidak laku dalam 3 hari dan dikembalikan.",
					{ items: { [m.item]: m.qty } }, 14, now());
			}
		}
	}

	routes["GET /v1/market"] = (me) => {
		sweepMarket();
		const today = h.dayOf(now()) * DAY;
		return [200, { listings: q.mkList.all(now() - MARKET_DAYS * DAY).map((m) => ({ ...m, mine: m.seller === me.id,
			seller: undefined })), mine: q.mkMine.all(me.id), left_today: Math.max(0, MARKET_DAILY - q.mkToday.get(me.id, today).n),
			tax: MARKET_TAX, items: h.CODE_ITEMS }];
	};

	routes["POST /v1/market/sell"] = (me, body) => {
		const item = String(body.item || "");
		if (!h.CODE_ITEMS.includes(item)) return [400, { error: "Item ini tidak bisa dijual di pasar." }];
		const qty = h.clampInt(body.qty, 0, MARKET_QTY_MAX);
		const price = h.clampInt(body.price, 0, MARKET_PRICE_MAX);
		if (qty < 1 || price < 1) return [400, { error: "Jumlah dan harga harus lebih dari nol." }];
		if (q.mkToday.get(me.id, h.dayOf(now()) * DAY).n >= MARKET_DAILY) {
			return [429, { error: `Batas ${MARKET_DAILY} dagangan per hari tercapai.` }];
		}
		const id = q.mkAdd.run(me.id, me.name, item, qty, price, now()).lastInsertRowid;
		return [200, { id: Number(id) }];
	};

	routes["POST /v1/market/buy"] = (me, body) => {
		const m = q.mkGet.get(h.clampInt(body.id, 0, Number.MAX_SAFE_INTEGER));
		if (!m || m.status !== "open" || m.created <= now() - MARKET_DAYS * DAY) {
			return [404, { error: "Dagangan sudah tidak tersedia." }];
		}
		if (m.seller === me.id) return [400, { error: "Tidak bisa membeli dagangan sendiri." }];
		if (q.mkClose.run("sold", me.id, now(), m.id).changes === 0) return [409, { error: "Dagangan baru saja terjual." }];
		const earn = Math.floor(m.price * (1 - MARKET_TAX));
		h.addMail(db, m.seller, "Dagangan Laku", `${me.name} membeli ${m.qty} item Tuan.`, { silver: earn }, 30, now());
		return [200, { item: m.item, qty: m.qty, price: m.price }];
	};

	routes["POST /v1/market/cancel"] = (me, body) => {
		const m = q.mkGet.get(h.clampInt(body.id, 0, Number.MAX_SAFE_INTEGER));
		if (!m || m.seller !== me.id) return [404, { error: "Dagangan tidak ditemukan." }];
		if (q.mkClose.run("cancelled", null, now(), m.id).changes === 0) return [409, { error: "Dagangan sudah terjual." }];
		h.addMail(db, me.id, "Dagangan Dibatalkan", "Dagangan Tuan ditarik dari pasar.", { items: { [m.item]: m.qty } }, 14, now());
		return [200, { ok: true }];
	};

	// --- Pemberitahuan untuk pekerja latar Android ---------------------------------------
	// ?since=<ms>: dagangan yang laku sejak waktu itu.
	routes["GET /v1/notices"] = (me, _body, params) => {
		const since = h.clampInt(params.get("since") || 0, 0, Number.MAX_SAFE_INTEGER);
		const mail = db.prepare(`SELECT COUNT(*) AS n FROM mail m WHERE (m.target = '*' OR m.target = ?) AND m.expires > ?
			AND m.created > ? AND NOT EXISTS (SELECT 1 FROM mail_claims c WHERE c.mail = m.id AND c.player = ?)`)
			.get(me.id, now(), since, me.id).n;
		return [200, { t: now(), mail, sold: q.mkSoldSince.get(me.id, since).n }];
	};

	// --- Verifikasi pembelian Google Play -------------------------------------------------
	// opts.iap = { packageName, serviceAccount: {client_email, private_key}, fetch? }
	// Tanpa konfigurasi: 503 "verifikasi tidak aktif" (klien memakai cek di perangkat seperti sebelumnya).
	const iap = ctx.opts.iap || loadIapConfig();
	const fetchFn = (iap && iap.fetch) || globalThis.fetch;
	let accessToken = null;

	async function googleToken() {
		if (accessToken && accessToken.exp > now() + 60000) return accessToken.value;
		const sa = iap.serviceAccount;
		const iat = Math.floor(now() / 1000);
		const b64 = (o) => Buffer.from(JSON.stringify(o)).toString("base64url");
		const unsigned = `${b64({ alg: "RS256", typ: "JWT" })}.${b64({ iss: sa.client_email,
			scope: "https://www.googleapis.com/auth/androidpublisher", aud: "https://oauth2.googleapis.com/token",
			iat, exp: iat + 3600 })}`;
		const sig = crypto.createSign("RSA-SHA256").update(unsigned).sign(sa.private_key, "base64url");
		const res = await fetchFn("https://oauth2.googleapis.com/token", { method: "POST",
			headers: { "Content-Type": "application/x-www-form-urlencoded" },
			body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${unsigned}.${sig}` });
		if (!res.ok) throw new Error(`token ${res.status}`);
		const data = await res.json();
		accessToken = { value: data.access_token, exp: now() + (data.expires_in || 3600) * 1000 };
		return accessToken.value;
	}

	routes["POST /v1/iap/verify"] = async (me, body) => {
		if (!iap) return [503, { error: "Verifikasi pembelian tidak aktif di server ini.", disabled: true }];
		const product = String(body.product || "").replace(/[^a-z0-9_.]/g, "").slice(0, 64);
		const token = String(body.token || "").slice(0, 600);
		if (!product || token.length < 10) return [400, { error: "Data pembelian tidak lengkap." }];
		const used = q.iapUsed.get(token);
		if (used) {
			return used.player === me.id && used.product === product ? [200, { valid: true, repeat: true }]
				: [409, { error: "Token pembelian sudah dipakai akun lain." }];
		}
		let purchase;
		try {
			const url = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${
				encodeURIComponent(iap.packageName)}/purchases/products/${encodeURIComponent(product)}/tokens/${
				encodeURIComponent(token)}`;
			const res = await fetchFn(url, { headers: { Authorization: `Bearer ${await googleToken()}` } });
			if (res.status === 400 || res.status === 404 || res.status === 410) {
				return [402, { error: "Pembelian tidak dikenal Google Play." }];
			}
			if (!res.ok) return [502, { error: "Google Play tidak bisa dihubungi. Coba lagi nanti." }];
			purchase = await res.json();
		} catch (e) {
			console.error("iap", e.message);
			return [502, { error: "Google Play tidak bisa dihubungi. Coba lagi nanti." }];
		}
		if (purchase.purchaseState !== 0) return [402, { error: "Pembelian belum selesai atau dibatalkan." }];
		q.iapAdd.run(token, me.id, product, now());
		return [200, { valid: true, order: String(purchase.orderId || "") }];
	};

	// --- Dasbor admin --------------------------------------------------------------------
	const adminToken = ctx.opts.adminToken ?? process.env.ADMIN_TOKEN ?? "";
	const page = fs.readFileSync(path.join(__dirname, "admin.html"), "utf8");
	open.add("GET /admin");
	routes["GET /admin"] = () => [200, page, "text/html; charset=utf-8"];

	const admin = (fn) => {
		return (_me, body, params, req) => {
			if (!adminToken) return [403, { error: "Dasbor admin nonaktif: set ADMIN_TOKEN." }];
			const given = String(req.headers["x-admin-token"] || "");
			const a = crypto.createHash("sha256").update(given).digest();
			const b = crypto.createHash("sha256").update(adminToken).digest();
			if (!crypto.timingSafeEqual(a, b)) return [401, { error: "Token admin salah." }];
			return fn(body, params);
		};
	};
	const adminRoutes = {
		"GET /admin/api/overview": () => {
			const n = (sql, ...a) => db.prepare(sql).get(...a).n;
			const t = now();
			return [200, { players: n("SELECT COUNT(*) AS n FROM players"),
				active_1d: n("SELECT COUNT(*) AS n FROM players WHERE seen > ?", t - DAY),
				active_7d: n("SELECT COUNT(*) AS n FROM players WHERE seen > ?", t - 7 * DAY),
				new_7d: n("SELECT COUNT(*) AS n FROM players WHERE created > ?", t - 7 * DAY),
				reports_open: n("SELECT COUNT(DISTINCT message) AS n FROM reports r JOIN chat c ON c.id = r.message WHERE c.hidden = 0"),
				market_open: n("SELECT COUNT(*) AS n FROM market WHERE status = 'open'"),
				iap_verified: n("SELECT COUNT(*) AS n FROM iap_tokens"),
				season: seasonNumber(seasonOf(t)), season_board: seasonBoard(seasonOf(t)) }];
		},
		"GET /admin/api/stats": (_b, params) => [200, h.statsSummary(db, h.clampInt(params.get("days") || 14, 1, 90), now())],
		"GET /admin/api/codes": () => [200, { codes: db.prepare("SELECT * FROM codes ORDER BY expires DESC").all()
			.map((c) => ({ ...c, reward: JSON.parse(c.reward) })) }],
		"POST /admin/api/codes": (body) => {
			const code = String(body.code || "").toUpperCase().replace(/[^A-Z0-9]/g, "");
			if (code.length < 4) return [400, { error: "Kode minimal 4 huruf/angka." }];
			h.addCode(db, code, body.reward || {}, h.clampInt(body.max || 1000, 1, 1e7),
				now() + h.clampInt(body.days || 30, 1, 365) * DAY);
			return [200, { code }];
		},
		"POST /admin/api/mail": (body) => {
			let target = "*";
			if (body.to && body.to !== "all") {
				const p = findByCode(body.to);
				if (!p) return [404, { error: "Pemain dengan kode itu tidak ditemukan." }];
				target = p.id;
			}
			if (!body.title || !body.body) return [400, { error: "Judul dan isi wajib diisi." }];
			h.addMail(db, target, body.title, body.body, body.reward || {}, h.clampInt(body.days || 14, 1, 90), now());
			return [200, { ok: true, target: target === "*" ? "semua" : body.to }];
		},
		"GET /admin/api/reports": () => [200, { reports: db.prepare(`SELECT c.id, c.name, c.text, c.alliance, c.hidden,
			COUNT(r.reporter) AS n FROM reports r JOIN chat c ON c.id = r.message GROUP BY c.id ORDER BY c.hidden, n DESC
			LIMIT 100`).all() }],
		"POST /admin/api/reports/hide": (body) => {
			db.prepare("UPDATE chat SET hidden = ? WHERE id = ?").run(body.hidden === false ? 0 : 1,
				h.clampInt(body.id, 0, Number.MAX_SAFE_INTEGER));
			return [200, { ok: true }];
		},
	};
	for (const [k, fn] of Object.entries(adminRoutes)) {
		open.add(k);
		routes[k] = admin(fn);
	}
}

// Kredensial verifikasi pembelian dari environment:
//   IAP_PACKAGE=com.microaltech.tuannusantara IAP_SERVICE_ACCOUNT=/path/ke/akun-layanan.json
function loadIapConfig() {
	const file = process.env.IAP_SERVICE_ACCOUNT;
	if (!file || !process.env.IAP_PACKAGE) return null;
	return { packageName: process.env.IAP_PACKAGE, serviceAccount: JSON.parse(fs.readFileSync(file, "utf8")) };
}

module.exports = { install, REFERRAL_STAGE, REFERRAL_REWARD, SEASON_REWARDS, MARKET_TAX };
