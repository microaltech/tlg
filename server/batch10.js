"use strict";
// Fitur server tambahan (batch 10):
// - Umpan balik pemain (teks + tangkapan layar) dan balasan admin lewat kotak surat.
// - Jadwal acara: pengaturan konfigurasi yang menyala/mati otomatis menurut tanggal.
// - Uji A/B: eksperimen di konfigurasi, kelompok dipilih di perangkat, hasil di statistik.
// - Raid aliansi 3 hari: anggota bergiliran menyerang benteng, hadiah menurut kontribusi.
// - Cadangan database harian (VACUUM INTO), halaman /status, dan peringatan webhook.

const fs = require("node:fs");
const path = require("node:path");
const { CONFIG_SPEC } = require("./batch9.js");

const FEEDBACK_DAILY = 5;
const FEEDBACK_TEXT = 1000;
const SHOT_MAX = 400 * 1024; // byte gambar JPEG setelah base64 didekode
const RAID_DAYS = 3;
const RAID_ATTACKS = 2;
const RAID_HP_MIN = 300000;
const RAID_REWARDS = [ // [porsi kerusakan minimal, hadiah]
	[0.2, { gold: 150, items: { star_stone: 2 } }],
	[0.05, { gold: 80, items: { star_stone: 1 } }],
	[0, { gold: 40, items: { recruit_ticket: 1 } }],
];
const BACKUP_KEEP = 7;
const ALERT_ERRORS = 20; // galat 5xx dalam 10 menit sebelum peringatan dikirim

// Eksperimen A/B: [{id, variants: [{name, overrides: {yield_bonus|gacha_discount: angka}}]}]
CONFIG_SPEC.experiments = {
	def: [],
	list: true,
	clean(v) {
		if (!Array.isArray(v)) return [];
		return v.slice(0, 5).map((e) => ({
			id: String(e?.id || "").toLowerCase().replace(/[^a-z0-9_]/g, "").slice(0, 24),
			variants: (Array.isArray(e?.variants) ? e.variants : []).slice(0, 4).map((x) => {
				const overrides = {};
				for (const k of ["yield_bonus", "gacha_discount"]) {
					if (x?.overrides && x.overrides[k] !== undefined) {
						const spec = CONFIG_SPEC[k];
						overrides[k] = Math.min(spec.max, Math.max(spec.min, Number(x.overrides[k]) || 0));
					}
				}
				return { name: String(x?.name || "").toLowerCase().replace(/[^a-z0-9_]/g, "").slice(0, 16) || "a", overrides };
			}),
		})).filter((e) => e.id && e.variants.length >= 2);
	},
};

function install(ctx) {
	const { db, routes, open, now, random, h, admin, configLayers, metrics } = ctx;
	const DAY = 86400000;
	db.exec(`
		CREATE TABLE IF NOT EXISTS feedback (id INTEGER PRIMARY KEY AUTOINCREMENT, player TEXT NOT NULL, name TEXT NOT NULL,
			kind TEXT NOT NULL, text TEXT NOT NULL, shot BLOB, version TEXT NOT NULL, device TEXT NOT NULL,
			lang TEXT NOT NULL, t INTEGER NOT NULL, reply TEXT);
		CREATE TABLE IF NOT EXISTS schedule (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL,
			start INTEGER NOT NULL, end INTEGER NOT NULL, overrides TEXT NOT NULL);
		CREATE TABLE IF NOT EXISTS raid_hits (raid INTEGER NOT NULL, player TEXT NOT NULL, alliance TEXT NOT NULL,
			damage INTEGER NOT NULL, day INTEGER NOT NULL, n INTEGER NOT NULL, PRIMARY KEY (raid, player));
		CREATE TABLE IF NOT EXISTS raids (raid INTEGER NOT NULL, alliance TEXT NOT NULL, hp_max INTEGER NOT NULL,
			PRIMARY KEY (raid, alliance));
		CREATE TABLE IF NOT EXISTS raid_claims (raid INTEGER NOT NULL, player TEXT NOT NULL, PRIMARY KEY (raid, player));
	`);
	const q = {
		fbAdd: db.prepare(`INSERT INTO feedback (player, name, kind, text, shot, version, device, lang, t)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`),
		fbToday: db.prepare("SELECT COUNT(*) AS n FROM feedback WHERE player = ? AND t > ?"),
		fbList: db.prepare(`SELECT id, player, name, kind, text, version, device, lang, t, reply, shot IS NOT NULL AS has_shot
			FROM feedback ORDER BY id DESC LIMIT 100`),
		fbGet: db.prepare("SELECT * FROM feedback WHERE id = ?"),
		fbReply: db.prepare("UPDATE feedback SET reply = ? WHERE id = ?"),
		schActive: db.prepare("SELECT * FROM schedule WHERE start <= ? AND end > ? ORDER BY start"),
		schAll: db.prepare("SELECT * FROM schedule WHERE end > ? ORDER BY start LIMIT 100"),
		schAdd: db.prepare("INSERT INTO schedule (title, start, end, overrides) VALUES (?, ?, ?, ?)"),
		schDel: db.prepare("DELETE FROM schedule WHERE id = ?"),
		raidGet: db.prepare("SELECT * FROM raids WHERE raid = ? AND alliance = ?"),
		raidAdd: db.prepare("INSERT OR IGNORE INTO raids (raid, alliance, hp_max) VALUES (?, ?, ?)"),
		raidPower: db.prepare("SELECT COALESCE(SUM(power), 0) AS p FROM players WHERE alliance = ? AND seen > ?"),
		hitGet: db.prepare("SELECT * FROM raid_hits WHERE raid = ? AND player = ?"),
		hitAdd: db.prepare(`INSERT INTO raid_hits (raid, player, alliance, damage, day, n) VALUES (?, ?, ?, ?, ?, 1)
			ON CONFLICT (raid, player) DO UPDATE SET damage = damage + excluded.damage,
			n = CASE WHEN day = excluded.day THEN n + 1 ELSE 1 END, day = excluded.day`),
		hitTotal: db.prepare("SELECT COALESCE(SUM(damage), 0) AS d FROM raid_hits WHERE raid = ? AND alliance = ?"),
		hitTop: db.prepare(`SELECT p.name, r.damage FROM raid_hits r JOIN players p ON p.id = r.player
			WHERE r.raid = ? AND r.alliance = ? ORDER BY r.damage DESC LIMIT 20`),
		claimAdd: db.prepare("INSERT OR IGNORE INTO raid_claims (raid, player) VALUES (?, ?)"),
		claimGet: db.prepare("SELECT 1 AS x FROM raid_claims WHERE raid = ? AND player = ?"),
	};

	// --- Umpan balik ------------------------------------------------------------------------
	routes["POST /v1/feedback"] = (me, body) => {
		const text = String(body.text || "").trim().slice(0, FEEDBACK_TEXT);
		if (text.length < 5) return [400, { error: "Tulis minimal beberapa kata." }];
		if (q.fbToday.get(me.id, now() - DAY).n >= FEEDBACK_DAILY) return [429, { error: "Batas laporan hari ini tercapai." }];
		let shot = null;
		if (body.screenshot) {
			const buf = Buffer.from(String(body.screenshot), "base64");
			// Hanya JPEG (FF D8 FF) atau PNG (89 50 4E 47) yang disimpan.
			const ok = buf.length > 4 && ((buf[0] === 0xff && buf[1] === 0xd8) || (buf[0] === 0x89 && buf[1] === 0x50));
			if (ok && buf.length <= SHOT_MAX) shot = buf;
		}
		q.fbAdd.run(me.id, me.name, body.kind === "bug" ? "bug" : "saran", text, shot,
			String(body.version || "").slice(0, 16), String(body.device || "").slice(0, 64),
			String(body.lang || "").slice(0, 5), now());
		return [200, { ok: true }];
	};

	// --- Jadwal acara -----------------------------------------------------------------------
	configLayers.push(() => {
		const out = {};
		for (const r of q.schActive.all(now(), now())) Object.assign(out, JSON.parse(r.overrides));
		return out;
	});

	function cleanOverrides(raw) {
		const out = {};
		for (const [k, v] of Object.entries(raw || {})) {
			const spec = CONFIG_SPEC[k];
			if (!spec || spec.list) continue;
			if (spec.obj) {
				if (v && typeof v === "object") {
					out[k] = { id: String(v.id || "").slice(0, 32), title: String(v.title || "").slice(0, 60),
						body: String(v.body || "").slice(0, 500) };
				}
			} else if (spec.str) {
				out[k] = String(v ?? "").toLowerCase().replace(/[^a-z0-9_]/g, "").slice(0, spec.str);
			} else if (Number.isFinite(Number(v))) {
				out[k] = Math.min(spec.max, Math.max(spec.min, Number(v)));
			}
		}
		return out;
	}

	// --- Raid aliansi ---------------------------------------------------------------------------
	const raidOf = (t) => Math.floor(h.dayOf(t) / RAID_DAYS);

	function raidFor(raid, alliance) {
		let r = q.raidGet.get(raid, alliance);
		if (!r) {
			q.raidAdd.run(raid, alliance, Math.max(RAID_HP_MIN, q.raidPower.get(alliance, now() - 7 * DAY).p * 3));
			r = q.raidGet.get(raid, alliance);
		}
		return r;
	}

	function standing(raid, me) {
		if (!me.alliance) return null;
		const r = q.raidGet.get(raid, me.alliance);
		if (!r) return { hp_max: 0, damage: 0, defeated: false, mine: 0, share: 0 };
		const total = q.hitTotal.get(raid, me.alliance).d;
		const mine = q.hitGet.get(raid, me.id)?.damage || 0;
		return { hp_max: r.hp_max, damage: total, defeated: total >= r.hp_max, mine, share: total ? mine / total : 0 };
	}

	function rewardFor(st) {
		if (!st || st.mine <= 0) return null;
		const tier = RAID_REWARDS.find(([min]) => st.share >= min)[1];
		if (st.defeated) return tier;
		// Benteng tidak runtuh: setengah hadiah.
		return { gold: Math.floor(tier.gold / 2), items: {} };
	}

	routes["GET /v1/raid"] = (me) => {
		if (!me.alliance) return [400, { error: "Bergabunglah dengan aliansi dulu." }];
		const raid = raidOf(now());
		const r = raidFor(raid, me.alliance);
		const hit = q.hitGet.get(raid, me.id);
		const used = hit && hit.day === h.dayOf(now()) ? hit.n : 0;
		const last = standing(raid - 1, me);
		return [200, { raid, hp_max: r.hp_max, ...standing(raid, me), attacks_left: Math.max(0, RAID_ATTACKS - used),
			top: q.hitTop.all(raid, me.alliance), ends_in: (raid + 1) * RAID_DAYS * DAY - now(),
			last, last_reward: rewardFor(last), last_claimed: !!q.claimGet.get(raid - 1, me.id) }];
	};

	routes["POST /v1/raid/attack"] = (me) => {
		if (!me.alliance) return [400, { error: "Bergabunglah dengan aliansi dulu." }];
		const raid = raidOf(now());
		const r = raidFor(raid, me.alliance);
		if (q.hitTotal.get(raid, me.alliance).d >= r.hp_max) return [409, { error: "Benteng sudah runtuh. Tunggu raid berikutnya." }];
		const hit = q.hitGet.get(raid, me.id);
		if (hit && hit.day === h.dayOf(now()) && hit.n >= RAID_ATTACKS) return [429, { error: "Serangan raid hari ini habis." }];
		const damage = Math.max(1, Math.round(Math.max(1, me.power) * (0.8 + 0.4 * random())));
		q.hitAdd.run(raid, me.id, me.alliance, damage, h.dayOf(now()));
		return [200, { damage, ...standing(raid, me) }];
	};

	routes["POST /v1/raid/claim"] = (me) => {
		const raid = raidOf(now()) - 1;
		const reward = rewardFor(standing(raid, me));
		if (!reward) return [400, { error: "Tuan tidak ikut raid sebelumnya." }];
		if (q.claimAdd.run(raid, me.id).changes === 0) return [409, { error: "Hadiah raid sudah diambil." }];
		return [200, { raid, reward: h.cleanReward(reward) }];
	};

	// --- Cadangan, status, dan peringatan -------------------------------------------------------
	const backupDir = ctx.opts.backupDir ?? process.env.BACKUP_DIR ?? "";
	let lastBackup = null;
	function backup() {
		if (!backupDir) return null;
		fs.mkdirSync(backupDir, { recursive: true });
		const file = path.join(backupDir, `tlg-${new Date(now()).toISOString().slice(0, 10)}.db`);
		if (!fs.existsSync(file)) db.exec(`VACUUM INTO '${file.replace(/'/g, "''")}'`);
		const old = fs.readdirSync(backupDir).filter((f) => /^tlg-\d{4}-\d{2}-\d{2}\.db$/.test(f)).sort();
		for (const f of old.slice(0, Math.max(0, old.length - BACKUP_KEEP))) fs.unlinkSync(path.join(backupDir, f));
		lastBackup = { file: path.basename(file), t: now() };
		return lastBackup;
	}
	if (backupDir && !ctx.opts.noTimers) {
		backup();
		setInterval(backup, 6 * 3600000).unref(); // sekali per tanggal (file yang sudah ada dilewati)
	}

	const webhook = ctx.opts.alertWebhook ?? process.env.ALERT_WEBHOOK ?? "";
	let lastAlert = 0;
	function checkAlert() {
		const t = Date.now();
		metrics.requests = metrics.requests.filter((x) => x > t - 3600000);
		metrics.errors = metrics.errors.filter((x) => x > t - 3600000);
		const recent = metrics.errors.filter((x) => x > t - 600000).length;
		if (webhook && recent >= ALERT_ERRORS && t - lastAlert > 3600000) {
			lastAlert = t;
			fetch(webhook, { method: "POST", headers: { "Content-Type": "application/json" },
				body: JSON.stringify({ text: `Server Tuan Nusantara: ${recent} galat dalam 10 menit terakhir.` }) })
				.catch((e) => console.error("alert", e.message));
		}
		return recent;
	}
	if (!ctx.opts.noTimers) setInterval(checkAlert, 60000).unref();

	open.add("GET /status");
	routes["GET /status"] = () => {
		const recent = checkAlert();
		return [200, { ok: recent < ALERT_ERRORS, uptime_s: Math.round((Date.now() - metrics.started) / 1000),
			players: db.prepare("SELECT COUNT(*) AS n FROM players").get().n,
			active_1d: db.prepare("SELECT COUNT(*) AS n FROM players WHERE seen > ?").get(now() - DAY).n,
			requests_1h: metrics.requests.length, errors_1h: metrics.errors.length, errors_10m: recent,
			last_backup: lastBackup }];
	};

	// --- Dasbor admin -------------------------------------------------------------------------
	const adminRoutes = {
		"GET /admin/api/feedback": () => [200, { feedback: q.fbList.all().map((f) => ({ ...f, has_shot: !!f.has_shot })) }],
		"GET /admin/api/feedback/shot": (_b, params) => {
			const f = q.fbGet.get(h.clampInt(params.get("id"), 0, Number.MAX_SAFE_INTEGER));
			if (!f || !f.shot) return [404, { error: "Tidak ada gambar." }];
			const shot = Buffer.from(f.shot);
			return [200, shot, shot[0] === 0x89 ? "image/png" : "image/jpeg"];
		},
		"POST /admin/api/feedback/reply": (body) => {
			const f = q.fbGet.get(h.clampInt(body.id, 0, Number.MAX_SAFE_INTEGER));
			const text = String(body.text || "").trim();
			if (!f || !text) return [400, { error: "Laporan atau balasan kosong." }];
			q.fbReply.run(text.slice(0, 500), f.id);
			h.addMail(db, f.player, "Balasan Pengembang", text, body.reward || {}, 30, now());
			return [200, { ok: true }];
		},
		"GET /admin/api/schedule": () => [200, { schedule: q.schAll.all(now()).map((r) => ({ ...r,
			overrides: JSON.parse(r.overrides), active: r.start <= now() && r.end > now() })) }],
		"POST /admin/api/schedule": (body) => {
			const start = Date.parse(body.start);
			const end = Date.parse(body.end);
			if (!Number.isFinite(start) || !Number.isFinite(end) || end <= start) {
				return [400, { error: "Tanggal mulai/selesai tidak valid." }];
			}
			const overrides = cleanOverrides(body.overrides);
			if (Object.keys(overrides).length === 0) return [400, { error: "Isi minimal satu pengaturan." }];
			const id = q.schAdd.run(String(body.title || "Acara").slice(0, 60), start, end, JSON.stringify(overrides))
				.lastInsertRowid;
			return [200, { id: Number(id), overrides }];
		},
		"POST /admin/api/schedule/delete": (body) => {
			q.schDel.run(h.clampInt(body.id, 0, Number.MAX_SAFE_INTEGER));
			return [200, { ok: true }];
		},
		"POST /admin/api/backup": () => (backupDir ? [200, backup()] : [400, { error: "Set BACKUP_DIR untuk cadangan." }]),
	};
	for (const [k, fn] of Object.entries(adminRoutes)) {
		open.add(k);
		routes[k] = admin(fn);
	}
	return { backup };
}

// Hasil eksperimen A/B dari statistik anonim: per varian, jumlah pemasangan, menit rata-rata, retensi H1/H7.
function experimentSummary(db, nowMs = Date.now()) {
	const today = Math.floor(nowMs / 86400000);
	const rows = db.prepare("SELECT install, day, payload FROM stats_reports").all();
	const first = {};
	const groups = {};
	const seen = new Set();
	const minutes = {};
	for (const r of rows) {
		const p = JSON.parse(r.payload);
		seen.add(`${r.install}:${r.day}`);
		if (first[r.install] === undefined || r.day < first[r.install]) first[r.install] = r.day;
		for (const [exp, v] of Object.entries(p.groups || {})) (groups[exp] ||= {})[r.install] = v;
		minutes[r.install] = Math.max(minutes[r.install] || 0, (p.play_seconds || 0) / 60);
	}
	const out = {};
	for (const [exp, members] of Object.entries(groups)) {
		out[exp] = {};
		for (const [install, variant] of Object.entries(members)) {
			const v = (out[exp][variant] ||= { installs: 0, minutes: 0, d1n: 0, d1: 0, d7n: 0, d7: 0 });
			v.installs += 1;
			v.minutes += minutes[install] || 0;
			const d = first[install];
			if (d <= today - 1) { v.d1n += 1; v.d1 += seen.has(`${install}:${d + 1}`) ? 1 : 0; }
			if (d <= today - 7) { v.d7n += 1; v.d7 += seen.has(`${install}:${d + 7}`) ? 1 : 0; }
		}
		for (const v of Object.values(out[exp])) {
			v.minutes = Math.round(v.minutes / v.installs);
			v.d1 = v.d1n ? Math.round((v.d1 / v.d1n) * 100) : null;
			v.d7 = v.d7n ? Math.round((v.d7 / v.d7n) * 100) : null;
			delete v.d1n;
			delete v.d7n;
		}
	}
	return out;
}

module.exports = { install, experimentSummary, RAID_REWARDS };
