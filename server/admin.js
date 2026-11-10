// Alat pengelola server: kode hadiah, surat, dan laporan statistik.
//
//   node server/admin.js add-code NUSANTARA2026 gold=100 items.recruit_ticket=1 --max 1000 --days 30
//   node server/admin.js list-codes
//   node server/admin.js send-mail --to all --title "Kompensasi" --body "Maaf atas gangguan." gold=100 --days 14
//   node server/admin.js send-mail --to KODETEMAN --title "..." --body "..." items.star_stone=1
//   node server/admin.js stats [hari]
//
// Database sama dengan server (DB_PATH, bawaan server/data/tlg.db). Hadiah dibatasi
// cleanReward() di server.js: emas maks. 1000, sumber daya maks. 10 juta, item maks. 10.
"use strict";
const path = require("node:path");
const { openDb, addCode, cleanReward, addMail, statsSummary } = require("./server.js");

const db = openDb(process.env.DB_PATH || path.join(__dirname, "data", "tlg.db"));
const [cmd, ...args] = process.argv.slice(2);

if (cmd === "add-code" && args[0]) {
	const reward = { items: {} };
	let max = 1000;
	let days = 30;
	for (let i = 1; i < args.length; i++) {
		if (args[i] === "--max") max = Number(args[++i]);
		else if (args[i] === "--days") days = Number(args[++i]);
		else {
			const [key, value] = args[i].split("=");
			if (key.startsWith("items.")) reward.items[key.slice(6)] = Number(value);
			else reward[key] = Number(value);
		}
	}
	addCode(db, args[0], reward, max, Date.now() + days * 86400000);
	console.log(`Kode ${args[0].toUpperCase()}: ${JSON.stringify(cleanReward(reward))}, maks. ${max} pemain, ${days} hari.`);
} else if (cmd === "list-codes") {
	for (const c of db.prepare("SELECT * FROM codes ORDER BY expires DESC").all()) {
		console.log(`${c.code}\t${c.uses}/${c.max_uses}\t${new Date(c.expires).toISOString().slice(0, 10)}\t${c.reward}`);
	}
} else if (cmd === "send-mail") {
	const reward = { items: {} };
	let to = "all";
	let title = "";
	let body = "";
	let days = 14;
	for (let i = 0; i < args.length; i++) {
		if (args[i] === "--to") to = args[++i];
		else if (args[i] === "--title") title = args[++i];
		else if (args[i] === "--body") body = args[++i];
		else if (args[i] === "--days") days = Number(args[++i]);
		else {
			const [key, value] = args[i].split("=");
			if (key.startsWith("items.")) reward.items[key.slice(6)] = Number(value);
			else reward[key] = Number(value);
		}
	}
	let target = "*";
	if (to !== "all") {
		const code = to.replace(/[^0-9a-f]/gi, "").toLowerCase();
		const found = db.prepare("SELECT id FROM players WHERE replace(id, '-', '') LIKE ?").all(code + "%");
		if (found.length !== 1) {
			console.log("Pemain dengan kode itu tidak ditemukan.");
			process.exit(1);
		}
		target = found[0].id;
	}
	if (!title || !body) {
		console.log("--title dan --body wajib diisi.");
		process.exit(1);
	}
	addMail(db, target, title, body, reward, days);
	console.log(`Surat "${title}" untuk ${to === "all" ? "semua pemain" : to}: ${JSON.stringify(cleanReward(reward))}, ${days} hari.`);
} else if (cmd === "stats") {
	// Ringkasan statistik anonim: pemasangan aktif, lama main, tahap, retensi, kejadian teratas.
	const sum = statsSummary(db, Number(args[0] || 14));
	console.log("hari        | aktif | baru | rata sesi | rata menit | median tahap | tutorial");
	for (const d of sum.days) {
		console.log(`${d.date}  | ${String(d.active).padStart(5)} | ${String(d.new).padStart(4)} | `
			+ `${d.sessions.toFixed(1).padStart(9)} | ${String(d.minutes).padStart(10)} | ${String(d.median_stage).padStart(12)} | `
			+ `${d.tutorial}%`);
	}
	console.log(`Retensi (${sum.retention.cohort} pemasangan): H1 ${sum.retention.d1}%, H7 ${sum.retention.d7}%`);
	console.log("Kejadian teratas:", sum.events.map(([k, v]) => `${k} ${v}`).join(", "));
} else {
	console.log("Pemakaian:\n  node server/admin.js add-code KODE gold=100 items.recruit_ticket=1 --max 1000 --days 30\n"
		+ "  node server/admin.js list-codes\n"
		+ "  node server/admin.js send-mail --to all|KODETEMAN --title \"...\" --body \"...\" gold=100 --days 14\n"
		+ "  node server/admin.js stats [hari]");
	process.exit(1);
}
