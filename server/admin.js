// Alat pengelola server: kode hadiah untuk promosi.
//
//   node server/admin.js add-code NUSANTARA2026 gold=100 items.recruit_ticket=1 --max 1000 --days 30
//   node server/admin.js list-codes
//
// Database sama dengan server (DB_PATH, bawaan server/data/tlg.db). Hadiah dibatasi
// cleanReward() di server.js: emas maks. 1000, sumber daya maks. 10 juta, item maks. 10.
"use strict";
const path = require("node:path");
const { openDb, addCode, cleanReward } = require("./server.js");

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
} else {
	console.log("Pemakaian:\n  node server/admin.js add-code KODE gold=100 items.recruit_ticket=1 --max 1000 --days 30\n"
		+ "  node server/admin.js list-codes");
	process.exit(1);
}
