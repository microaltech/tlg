"use strict";
// Fitur server tambahan (batch 9):
// - Save di server: cadangan otomatis, sumber kebenaran inventaris untuk Pasar Pemain,
//   dan deteksi lonjakan emas mencurigakan (ditandai untuk ditinjau di dasbor).
// - Pindah perangkat: kode pindah sekali pakai (24 jam) untuk memindahkan akun ke HP baru.
// - Konfigurasi jarak jauh: bonus hasil, diskon rekrut, rate-up, event, pengumuman,
//   dan versi minimum, diatur dari dasbor tanpa update aplikasi.
// - Laporan crash online (opt-in, sama dengan statistik anonim).

const crypto = require("node:crypto");

const SAVE_MAX = 600 * 1024;
const TRANSFER_HOURS = 24;
const TRANSFER_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
// Emas yang wajar didapat tanpa membeli: per jam bermain-nyata, ditambah cadangan tetap.
const GOLD_PER_HOUR = 120;
const GOLD_SLACK = 3000;
const CRASH_MAX = 8192;
const CRASH_DAILY = 20;

// Nilai bawaan & batas tiap kunci konfigurasi jarak jauh.
const CONFIG_SPEC = {
	yield_bonus: { def: 0, min: 0, max: 1 }, // +x semua hasil urusan (0.5 = +50%)
	gacha_discount: { def: 0, min: 0, max: 0.5 }, // potongan biaya rekrut emas
	rateup: { def: "", str: 32 }, // id Legenda unggulan (kosong = bergilir)
	event: { def: "", str: 32 }, // id event mingguan (kosong = bergilir)
	min_version: { def: 0, min: 0, max: 1e6 }, // version/code minimum; di bawahnya wajib update
	announcement: { def: null, obj: true }, // {id, title, body}
};

function install(ctx) {
	const { db, routes, open, now, h } = ctx;
	const DAY = 86400000;
	db.exec(`
		CREATE TABLE IF NOT EXISTS saves (player TEXT PRIMARY KEY, data TEXT NOT NULL, version TEXT NOT NULL,
			gold INTEGER NOT NULL, inventory TEXT NOT NULL, t INTEGER NOT NULL);
		CREATE TABLE IF NOT EXISTS transfers (code TEXT PRIMARY KEY, player TEXT NOT NULL, expires INTEGER NOT NULL);
		CREATE TABLE IF NOT EXISTS config (key TEXT PRIMARY KEY, value TEXT NOT NULL);
		CREATE TABLE IF NOT EXISTS crashes (id INTEGER PRIMARY KEY AUTOINCREMENT, install TEXT NOT NULL,
			version TEXT NOT NULL, device TEXT NOT NULL, gpu TEXT NOT NULL, report TEXT NOT NULL, t INTEGER NOT NULL);
		CREATE TABLE IF NOT EXISTS flags (id INTEGER PRIMARY KEY AUTOINCREMENT, player TEXT NOT NULL, reason TEXT NOT NULL,
			t INTEGER NOT NULL);
	`);
	const q = {
		saveGet: db.prepare("SELECT * FROM saves WHERE player = ?"),
		savePut: db.prepare(`INSERT INTO saves (player, data, version, gold, inventory, t) VALUES (?, ?, ?, ?, ?, ?)
			ON CONFLICT (player) DO UPDATE SET data = excluded.data, version = excluded.version, gold = excluded.gold,
			inventory = excluded.inventory, t = excluded.t`),
		invSet: db.prepare("UPDATE saves SET inventory = ? WHERE player = ?"),
		iapGold: db.prepare("SELECT COUNT(*) AS n FROM iap_tokens WHERE player = ? AND t > ?"),
		flagAdd: db.prepare("INSERT INTO flags (player, reason, t) VALUES (?, ?, ?)"),
		trAdd: db.prepare("INSERT INTO transfers (code, player, expires) VALUES (?, ?, ?)"),
		trGet: db.prepare("SELECT * FROM transfers WHERE code = ?"),
		trDel: db.prepare("DELETE FROM transfers WHERE code = ? OR player = ?"),
		byDevice: db.prepare("SELECT * FROM players WHERE device_hash = ?"),
		byId: db.prepare("SELECT * FROM players WHERE id = ?"),
		rebind: db.prepare("UPDATE players SET device_hash = ?, token = ? WHERE id = ?"),
		cfgAll: db.prepare("SELECT key, value FROM config"),
		cfgSet: db.prepare("INSERT INTO config (key, value) VALUES (?, ?) ON CONFLICT (key) DO UPDATE SET value = excluded.value"),
		crashAdd: db.prepare("INSERT INTO crashes (install, version, device, gpu, report, t) VALUES (?, ?, ?, ?, ?, ?)"),
		crashToday: db.prepare("SELECT COUNT(*) AS n FROM crashes WHERE install = ? AND t > ?"),
		openListings: db.prepare("SELECT COALESCE(SUM(qty), 0) AS n FROM market WHERE seller = ? AND item = ? AND status = 'open'"),
	};

	// --- Save di server ------------------------------------------------------------------
	function cleanInventory(raw) {
		const out = {};
		if (raw && typeof raw === "object") {
			for (const [k, v] of Object.entries(raw).slice(0, 200)) {
				if (/^[a-z0-9_]{1,32}$/.test(k)) out[k] = h.clampInt(v, 0, 1e9);
			}
		}
		return out;
	}

	routes["POST /v1/save"] = (me, body) => {
		const save = body.save;
		if (!save || typeof save !== "object" || Array.isArray(save)) return [400, { error: "Save tidak valid." }];
		const text = JSON.stringify(save);
		if (text.length > SAVE_MAX) return [413, { error: "Save terlalu besar." }];
		const gold = h.clampInt(save.gold, 0, 1e12);
		const prev = q.saveGet.get(me.id);
		// Lonjakan emas melebihi yang wajar sejak cadangan terakhir (tanpa pembelian terverifikasi): tandai.
		if (prev) {
			const hours = Math.max(0, (now() - prev.t) / 3600000);
			const bought = q.iapGold.get(me.id, prev.t).n;
			const allowed = GOLD_SLACK + hours * GOLD_PER_HOUR + bought * 10000;
			if (gold - prev.gold > allowed) {
				q.flagAdd.run(me.id, `emas +${gold - prev.gold} dalam ${hours.toFixed(1)} jam (batas ${Math.round(allowed)})`, now());
			}
		}
		q.savePut.run(me.id, text, String(body.version || "").slice(0, 16), gold,
			JSON.stringify(cleanInventory(save.inventory)), now());
		return [200, { ok: true, t: now() }];
	};

	routes["GET /v1/save"] = (me) => {
		const s = q.saveGet.get(me.id);
		return s ? [200, { save: JSON.parse(s.data), t: s.t, version: s.version }] : [404, { error: "Belum ada save di server." }];
	};

	// Pasar: jumlah item yang dijual harus ada di save server (dikurangi dagangan yang masih terbuka).
	const sell = routes["POST /v1/market/sell"];
	routes["POST /v1/market/sell"] = (me, body) => {
		const item0 = String(body.item || "");
		if (!h.CODE_ITEMS.includes(item0) || h.clampInt(body.qty, 0, 10) < 1) return sell(me, body); // pesan galat asli
		const s = q.saveGet.get(me.id);
		if (!s) return [409, { error: "Simpan progres ke server dulu (tersambung otomatis), lalu coba lagi." }];
		const inv = JSON.parse(s.inventory);
		const item = String(body.item || "");
		const qty = h.clampInt(body.qty, 0, 10);
		if ((inv[item] || 0) - q.openListings.get(me.id, item).n < qty) {
			return [409, { error: "Item di save server tidak cukup." }];
		}
		const res = sell(me, body);
		if (res[0] === 200) {
			inv[item] = (inv[item] || 0) - qty;
			q.invSet.run(JSON.stringify(inv), me.id);
		}
		return res;
	};

	// --- Pindah perangkat ------------------------------------------------------------------
	routes["POST /v1/account/transfer"] = (me) => {
		q.trDel.run("", me.id);
		let code = "";
		for (let i = 0; i < 8; i++) code += TRANSFER_ALPHABET[crypto.randomInt(TRANSFER_ALPHABET.length)];
		q.trAdd.run(code, me.id, now() + TRANSFER_HOURS * 3600000);
		return [200, { code, expires_in: TRANSFER_HOURS * 3600000 }];
	};

	// Tanpa token: HP baru menukar kode pindah + ID perangkatnya dengan akun lama.
	open.add("POST /v1/account/claim");
	routes["POST /v1/account/claim"] = (_me, body) => {
		const code = String(body.code || "").toUpperCase().replace(/[^A-Z0-9]/g, "");
		const device = String(body.device_id || "");
		if (device.length < 16) return [400, { error: "device_id minimal 16 karakter" }];
		const t = q.trGet.get(code);
		if (!t || t.expires < now()) return [404, { error: "Kode pindah salah atau sudah kedaluwarsa." }];
		const target = q.byId.get(t.player);
		if (!target) return [404, { error: "Akun tidak ditemukan." }];
		const hash = crypto.createHash("sha256").update(device).digest("hex");
		// Akun kosong yang sempat dibuat otomatis di HP baru dilepas dari perangkat ini (datanya tetap ada).
		const other = q.byDevice.get(hash);
		if (other && other.id !== target.id) {
			q.rebind.run(`lepas:${crypto.randomUUID()}`, crypto.randomBytes(24).toString("hex"), other.id);
		}
		const token = crypto.randomBytes(24).toString("hex");
		q.rebind.run(hash, token, target.id);
		q.trDel.run(code, "");
		const s = q.saveGet.get(target.id);
		return [200, { token, player: { id: target.id, name: target.name }, save: s ? JSON.parse(s.data) : null }];
	};

	// --- Konfigurasi jarak jauh -------------------------------------------------------------
	function cleanConfigValue(key, v) {
		const spec = CONFIG_SPEC[key];
		if (spec.list) return spec.clean(v);
		if (spec.obj) {
			if (!v || typeof v !== "object") return null;
			return { id: String(v.id || "").slice(0, 32), title: String(v.title || "").slice(0, 60),
				body: String(v.body || "").slice(0, 500) };
		}
		if (spec.str) return String(v ?? "").toLowerCase().replace(/[^a-z0-9_]/g, "").slice(0, spec.str);
		const n = Number(v);
		return Number.isFinite(n) ? Math.min(spec.max, Math.max(spec.min, n)) : spec.def;
	}

	function config() {
		const out = {};
		for (const [k, spec] of Object.entries(CONFIG_SPEC)) out[k] = spec.def;
		for (const r of q.cfgAll.all()) if (CONFIG_SPEC[r.key]) out[r.key] = JSON.parse(r.value);
		// Lapisan tambahan (jadwal acara, eksperimen) dari batch10.js.
		for (const layer of ctx.configLayers || []) Object.assign(out, layer(out));
		return out;
	}

	open.add("GET /v1/config");
	routes["GET /v1/config"] = () => [200, config()];

	// --- Laporan crash (opt-in) --------------------------------------------------------------
	open.add("POST /v1/crash");
	routes["POST /v1/crash"] = (_me, body) => {
		const install = String(body.install || "").replace(/[^0-9a-f]/gi, "").slice(0, 32);
		if (install.length < 16) return [400, { error: "install tidak valid" }];
		if (q.crashToday.get(install, now() - DAY).n >= CRASH_DAILY) return [429, { error: "Terlalu banyak laporan." }];
		q.crashAdd.run(install, String(body.version || "").slice(0, 16), String(body.device || "").slice(0, 64),
			String(body.gpu || "").slice(0, 64), String(body.report || "").slice(0, CRASH_MAX), now());
		return [200, { ok: true }];
	};

	// --- Dasbor admin ---------------------------------------------------------------------
	const adminRoutes = {
		"GET /admin/api/config": () => [200, { config: config(), spec: CONFIG_SPEC }],
		"POST /admin/api/config": (body) => {
			for (const [k, v] of Object.entries(body || {})) {
				if (CONFIG_SPEC[k]) q.cfgSet.run(k, JSON.stringify(cleanConfigValue(k, v)));
			}
			return [200, { config: config() }];
		},
		"GET /admin/api/crashes": () => [200, {
			groups: db.prepare(`SELECT version, device, gpu, COUNT(*) AS n, MAX(t) AS last FROM crashes
				GROUP BY version, device, gpu ORDER BY n DESC LIMIT 50`).all(),
			recent: db.prepare("SELECT id, version, device, gpu, report, t FROM crashes ORDER BY id DESC LIMIT 20").all() }],
		"GET /admin/api/flags": () => [200, { flags: db.prepare(`SELECT f.id, f.reason, f.t, p.name, p.id AS player
			FROM flags f JOIN players p ON p.id = f.player ORDER BY f.id DESC LIMIT 100`).all() }],
	};
	for (const [k, fn] of Object.entries(adminRoutes)) {
		open.add(k);
		routes[k] = ctx.admin(fn);
	}
}

module.exports = { install, CONFIG_SPEC };
