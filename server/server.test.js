// Tes server: node --test server/
"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { createServer } = require("./server.js");

async function start(opts = {}) {
	let t = 1_700_000_000_000;
	const server = createServer({ ...opts, now: () => t, random: opts.random || (() => 0.5) });
	await new Promise((r) => server.listen(0, r));
	const base = `http://127.0.0.1:${server.address().port}`;
	const call = async (method, path, body, token, headers = {}) => {
		const res = await fetch(base + path, {
			method, body: body ? JSON.stringify(body) : undefined,
			headers: { ...(token ? { Authorization: `Bearer ${token}` } : {}), ...headers },
		});
		const text = await res.text();
		let data;
		try { data = JSON.parse(text); } catch { data = text; }
		return { status: res.status, data, type: res.headers.get("content-type") };
	};
	return { server, call, tick: (ms) => { t += ms; }, now: () => t };
}

async function login(call, device, name) {
	const r = await call("POST", "/v1/auth/device", { device_id: device.padEnd(16, "x"), name });
	assert.equal(r.status, 200);
	return r.data;
}

test("akun perangkat stabil dan profil tersimpan", async () => {
	const { server, call } = await start();
	try {
		assert.equal((await call("POST", "/v1/auth/device", { device_id: "pendek" })).status, 400);
		const a = await login(call, "perangkat-a", "Wira");
		const again = await login(call, "perangkat-a", "Lain");
		assert.equal(a.player.id, again.player.id, "perangkat sama = akun sama");
		assert.equal(again.player.name, "Wira");
		assert.equal((await call("POST", "/v1/profile", { power: 5 })).status, 401, "tanpa token ditolak");
		const p = await call("POST", "/v1/profile", { name: "Wira <b>", power: 1234, stage: 40, alliance: "garuda",
			portrait: "lord_batik" }, a.token);
		assert.equal(p.data.player.power, 1234);
		assert.equal(p.data.player.name, "Wira b");
		assert.equal(p.data.player.alliance, "garuda");
		const bad = await call("POST", "/v1/profile", { alliance: "palsu", power: -5 }, a.token);
		assert.equal(bad.data.player.alliance, null);
		assert.equal(bad.data.player.power, 0);
		assert.equal((await call("GET", "/health")).data.players, 1);
	} finally { server.close(); }
});

test("papan peringkat dan aliansi", async () => {
	const { server, call } = await start();
	try {
		const tokens = [];
		for (const [i, power] of [[1, 300], [2, 900], [3, 600]].entries()) {
			const a = await login(call, `dev-${i}`, `Tuan ${i}`);
			await call("POST", "/v1/profile", { power: power[1], alliance: i === 0 ? "macan" : "garuda" }, a.token);
			tokens.push(a.token);
		}
		const lb = await call("GET", "/v1/leaderboard?cat=power&limit=2", null, tokens[0]);
		assert.deepEqual(lb.data.top.map((p) => p.value), [900, 600]);
		assert.equal(lb.data.me.rank, 3);
		assert.equal(lb.data.players, 3);
		const al = await call("GET", "/v1/alliances");
		assert.deepEqual(al.data.alliances.find((a) => a.id === "garuda"), { id: "garuda", members: 2, power: 1500 });
		const sql = await call("GET", "/v1/leaderboard?cat=power;DROP", null, tokens[0]);
		assert.equal(sql.data.category, "power", "kategori tak dikenal kembali ke power");
	} finally { server.close(); }
});

test("chat aliansi: hanya sesama aliansi, filter, jeda", async () => {
	const { server, call, tick } = await start();
	try {
		const a = await login(call, "chat-a", "Ana");
		const b = await login(call, "chat-b", "Budi");
		const c = await login(call, "chat-c", "Cici");
		await call("POST", "/v1/profile", { alliance: "teratai" }, a.token);
		await call("POST", "/v1/profile", { alliance: "teratai" }, b.token);
		await call("POST", "/v1/profile", { alliance: "macan" }, c.token);
		assert.equal((await call("POST", "/v1/chat", { text: "  " }, a.token)).status, 400);
		assert.equal((await call("POST", "/v1/chat", { text: "Halo dasar goblok" }, a.token)).status, 200);
		assert.equal((await call("POST", "/v1/chat", { text: "lagi" }, a.token)).status, 429, "jeda kirim");
		tick(3000);
		await call("POST", "/v1/chat", { text: "x".repeat(500) }, a.token);
		const seen = await call("GET", "/v1/chat?after=0", null, b.token);
		assert.equal(seen.data.messages.length, 2);
		assert.equal(seen.data.messages[0].text, "Halo dasar ******");
		assert.equal(seen.data.messages[1].text.length, 120);
		assert.equal(seen.data.messages[0].me, false);
		const after = await call("GET", `/v1/chat?after=${seen.data.messages[0].id}`, null, b.token);
		assert.equal(after.data.messages.length, 1, "hanya pesan baru");
		assert.equal((await call("GET", "/v1/chat", null, c.token)).data.messages.length, 0, "aliansi lain tak melihat");
	} finally { server.close(); }
});

test("arena: lawan sungguhan, hasil dihitung server, poin berpindah", async () => {
	const { server, call } = await start({ random: () => 0.0 });
	try {
		const a = await login(call, "arena-a", "Kuat");
		const b = await login(call, "arena-b", "Lemah");
		await call("POST", "/v1/profile", { power: 10000 }, a.token);
		await call("POST", "/v1/profile", { power: 100 }, b.token);
		const opp = await call("GET", "/v1/arena/opponents", null, a.token);
		assert.equal(opp.data.opponents.length, 1);
		assert.equal(opp.data.opponents[0].name, "Lemah");
		assert.equal((await call("POST", "/v1/arena/fight", { opponent_id: a.player.id }, a.token)).status, 404,
			"tidak bisa melawan diri sendiri");
		const r = await call("POST", "/v1/arena/fight", { opponent_id: b.player.id }, a.token);
		assert.equal(r.data.win, true);
		assert.equal(r.data.delta, 16);
		const lb = await call("GET", "/v1/arena/opponents", null, b.token);
		assert.equal(lb.data.rating, 1000 - 16, "poin lawan berkurang");
		for (let i = 0; i < 19; i++) await call("POST", "/v1/arena/fight", { opponent_id: b.player.id }, a.token);
		assert.equal((await call("POST", "/v1/arena/fight", { opponent_id: b.player.id }, a.token)).status, 429);
	} finally { server.close(); }
});

test("chat: laporkan pesan, disembunyikan setelah 3 laporan", async () => {
	const { server, call, tick } = await start();
	try {
		const users = [];
		for (let i = 0; i < 4; i++) {
			const u = await login(call, `lapor-${i}`, `P${i}`);
			await call("POST", "/v1/profile", { alliance: "garuda" }, u.token);
			users.push(u);
		}
		const sent = await call("POST", "/v1/chat", { text: "pesan buruk" }, users[0].token);
		const id = sent.data.id;
		assert.equal((await call("POST", "/v1/chat/report", { message_id: id }, users[0].token)).status, 400,
			"tidak bisa melaporkan diri sendiri");
		assert.equal((await call("POST", "/v1/chat/report", { message_id: 999 }, users[1].token)).status, 404);
		for (let i = 1; i <= 2; i++) {
			const r = await call("POST", "/v1/chat/report", { message_id: id }, users[i].token);
			assert.equal(r.data.hidden, false);
		}
		const again = await call("POST", "/v1/chat/report", { message_id: id }, users[1].token);
		assert.equal(again.data.hidden, false, "laporan ganda dari orang sama tidak dihitung");
		const r3 = await call("POST", "/v1/chat/report", { message_id: id }, users[3].token);
		assert.equal(r3.data.hidden, true);
		tick(5000);
		assert.equal((await call("GET", "/v1/chat?after=0", null, users[1].token)).data.messages.length, 0,
			"pesan tersembunyi tidak dikirim lagi");
	} finally { server.close(); }
});

test("teman, hadiah harian, dan kunjungan kota", async () => {
	const { server, call, tick } = await start();
	try {
		const a = await login(call, "teman-a", "Arya");
		const b = await login(call, "teman-b", "Bayu");
		await call("POST", "/v1/profile", { power: 500, city: { rank: 3, buildings: { istana: 4, pasar: 99999 },
			ships: 2, evil: "<script>" } }, b.token);
		const fb = await call("GET", "/v1/friends", null, b.token);
		assert.equal(fb.data.code.length, 8);
		assert.equal((await call("POST", "/v1/friends/add", { code: "zz" }, a.token)).status, 400);
		assert.equal((await call("POST", "/v1/friends/add", { code: a.player.code }, a.token)).status, 400,
			"tidak bisa berteman dengan diri sendiri");
		const add = await call("POST", "/v1/friends/add", { code: fb.data.code.toLowerCase() }, a.token);
		assert.equal(add.status, 200);
		assert.equal(add.data.friend.name, "Bayu");
		assert.equal((await call("GET", "/v1/friends", null, b.token)).data.friends.length, 1, "pertemanan dua arah");
		assert.equal((await call("POST", "/v1/gift", { to: b.player.id }, a.token)).status, 200);
		assert.equal((await call("POST", "/v1/gift", { to: b.player.id }, a.token)).status, 429, "sekali per hari");
		assert.equal((await call("POST", "/v1/gift", { to: "orang-asing" }, a.token)).status, 404);
		const inbox = await call("GET", "/v1/friends", null, b.token);
		assert.equal(inbox.data.inbox.length, 1);
		const claim = await call("POST", "/v1/gifts/claim", null, b.token);
		assert.deepEqual(claim.data, { claimed: 1, names: ["Arya"] });
		assert.equal((await call("POST", "/v1/gifts/claim", null, b.token)).data.claimed, 0);
		tick(86400000);
		assert.equal((await call("POST", "/v1/gift", { to: b.player.id }, a.token)).status, 200, "hari baru, kirim lagi");
		const visit = await call("GET", `/v1/player?id=${b.player.id}`, null, a.token);
		assert.equal(visit.data.city.buildings.istana, 4);
		assert.equal(visit.data.city.buildings.pasar, 99, "angka kota dibatasi");
		assert.equal(visit.data.city.evil, undefined, "kunci asing dibuang");
		assert.equal(visit.data.friend, true);
		await call("POST", "/v1/friends/remove", { id: b.player.id }, a.token);
		assert.equal((await call("GET", "/v1/friends", null, b.token)).data.friends.length, 0);
	} finally { server.close(); }
});

test("Raja Hari Ini dan titahnya", async () => {
	const { server, call, tick } = await start();
	try {
		const a = await login(call, "raja-a", "Wira");
		const b = await login(call, "raja-b", "Sekar");
		await call("POST", "/v1/profile", { power: 900 }, a.token);
		await call("POST", "/v1/profile", { power: 300 }, b.token);
		const k = await call("GET", "/v1/king", null, b.token);
		assert.equal(k.data.king.name, "Wira");
		assert.equal(k.data.me, false);
		assert.equal((await call("POST", "/v1/king/decree", { decree: "perak" }, b.token)).status, 403);
		assert.equal((await call("POST", "/v1/king/decree", { decree: "bebas" }, a.token)).status, 400);
		assert.equal((await call("POST", "/v1/king/decree", { decree: "perak" }, a.token)).status, 200);
		assert.equal((await call("POST", "/v1/king/decree", { decree: "pangan" }, a.token)).status, 400, "sekali sehari");
		await call("POST", "/v1/profile", { power: 5000 }, b.token);
		assert.equal((await call("GET", "/v1/king", null, b.token)).data.king.name, "Wira", "raja dikunci sepanjang hari");
		tick(86400000);
		const next = await call("GET", "/v1/king", null, b.token);
		assert.equal(next.data.king.name, "Sekar");
		assert.equal(next.data.decree, null);
	} finally { server.close(); }
});

test("Perang Wilayah Aliansi", async () => {
	const { server, call, tick } = await start();
	try {
		const a = await login(call, "gw-a", "Arya");
		const b = await login(call, "gw-b", "Bayu");
		const c = await login(call, "gw-c", "Citra");
		assert.equal((await call("POST", "/v1/guildwar/attack", { territory: 0 }, c.token)).status, 400, "butuh aliansi");
		await call("POST", "/v1/profile", { power: 10000, alliance: "garuda" }, a.token);
		await call("POST", "/v1/profile", { power: 2500, alliance: "macan" }, b.token);
		assert.equal((await call("POST", "/v1/guildwar/attack", { territory: 99 }, a.token)).status, 404);
		const hit = await call("POST", "/v1/guildwar/attack", { territory: 0 }, a.token);
		assert.equal(hit.data.points, 100, "akar 10000 x 1,0");
		await call("POST", "/v1/guildwar/attack", { territory: 0 }, b.token);
		await call("POST", "/v1/guildwar/attack", { territory: 1 }, b.token);
		await call("POST", "/v1/guildwar/attack", { territory: 2 }, b.token);
		assert.equal((await call("POST", "/v1/guildwar/attack", { territory: 2 }, b.token)).status, 429, "3 kali sehari");
		const board = await call("GET", "/v1/guildwar", null, a.token);
		assert.equal(board.data.territories[0].owner, "garuda");
		assert.equal(board.data.territories[1].owner, "macan");
		assert.equal(board.data.attacks_left, 2);
		tick(7 * 86400000);
		const after = await call("GET", "/v1/guildwar", null, b.token);
		assert.equal(after.data.last_won, 2, "macan menang 2 wilayah minggu lalu");
		assert.equal(after.data.attacks_left, 3);
		assert.equal(after.data.territories[0].owner, null, "minggu baru dimulai kosong");
	} finally { server.close(); }
});

test("Bos Dunia: kerusakan, batas harian, peringkat, hasil minggu lalu", async () => {
	const { server, call, tick } = await start();
	try {
		const a = await login(call, "bos-a", "Arya");
		const b = await login(call, "bos-b", "Bayu");
		await call("POST", "/v1/profile", { power: 50000 }, a.token);
		await call("POST", "/v1/profile", { power: 10000 }, b.token);
		const info = await call("GET", "/v1/worldboss", null, a.token);
		assert.equal(info.data.hp_max, 300000, "HP = 5x total kekuatan");
		assert.equal(info.data.attacks_left, 3);
		const hit = await call("POST", "/v1/worldboss/attack", null, a.token);
		assert.equal(hit.data.damage, 50000);
		await call("POST", "/v1/worldboss/attack", null, a.token);
		await call("POST", "/v1/worldboss/attack", null, a.token);
		assert.equal((await call("POST", "/v1/worldboss/attack", null, a.token)).status, 429, "3 kali sehari");
		await call("POST", "/v1/worldboss/attack", null, b.token);
		const mine = await call("GET", "/v1/worldboss", null, b.token);
		assert.equal(mine.data.me.rank, 2);
		assert.equal(mine.data.me.players, 2);
		assert.equal(mine.data.top[0].name, "Arya");
		assert.equal(mine.data.damage, 160000);
		tick(86400000);
		assert.equal((await call("POST", "/v1/worldboss/attack", null, a.token)).status, 200, "hari baru, serang lagi");
		await call("POST", "/v1/worldboss/attack", null, a.token);
		await call("POST", "/v1/worldboss/attack", null, a.token);
		const won = await call("GET", "/v1/worldboss", null, a.token);
		assert.equal(won.data.defeated, true, "bos tumbang");
		tick(7 * 86400000);
		const next = await call("GET", "/v1/worldboss", null, a.token);
		assert.equal(next.data.damage, 0, "minggu baru, bos baru");
		assert.deepEqual([next.data.last.rank, next.data.last.players, next.data.last.defeated], [1, 2, true]);
	} finally { server.close(); }
});

test("kode hadiah: batas, kuota, kedaluwarsa, sekali per pemain", async () => {
	const { server, call, tick } = await start();
	const { addCode } = require("./server.js");
	try {
		addCode(server.db, "promo1", { gold: 99999, silver: 500, items: { star_stone: 50, rahasia: 1 }, hack: 1 }, 2,
			1_700_000_000_000 + 86400000);
		const users = [];
		for (let i = 0; i < 3; i++) users.push(await login(call, `kode-${i}`, `Tuan ${i}`));
		const r = await call("POST", "/v1/redeem", { code: " Promo1 " }, users[0].token);
		assert.equal(r.status, 200);
		assert.deepEqual(r.data.reward, { gold: 1000, silver: 500, items: { star_stone: 10 } }, "hadiah dibatasi");
		assert.equal((await call("POST", "/v1/redeem", { code: "PROMO1" }, users[0].token)).status, 409, "sekali per pemain");
		assert.equal((await call("POST", "/v1/redeem", { code: "PROMO1" }, users[1].token)).status, 200);
		assert.equal((await call("POST", "/v1/redeem", { code: "PROMO1" }, users[2].token)).status, 410, "kuota habis");
		assert.equal((await call("POST", "/v1/redeem", { code: "TIDAKADA" }, users[2].token)).status, 404);
		addCode(server.db, "lama", { gold: 5 }, 10, 1_700_000_000_000 + 1000);
		tick(5000);
		assert.equal((await call("POST", "/v1/redeem", { code: "lama" }, users[2].token)).status, 404, "kedaluwarsa");
	} finally { server.close(); }
});

test("turnamen silat online: daftar, bagan, hasil", async () => {
	const { server, call, tick } = await start();
	try {
		// 1.700.000.000.000 ms = Selasa; maju ke hari Rabu agar jelas fase pendaftaran.
		const users = [];
		for (let i = 0; i < 5; i++) {
			const u = await login(call, `turnamen-${i}`, `Pesilat ${i}`);
			await call("POST", "/v1/profile", { power: 1000 * (i + 1) ** 2, city: { badges: ["joki", "palsu", "joki"] } }, u.token);
			users.push(u);
		}
		const visit = await call("GET", `/v1/player?id=${users[1].player.id}`, null, users[0].token);
		assert.deepEqual(visit.data.city.badges, ["joki"], "lencana disaring");
		const before = await call("GET", "/v1/tourney", null, users[0].token);
		assert.equal(before.data.phase, "register");
		assert.equal(before.data.bracket, null);
		for (const u of users) assert.equal((await call("POST", "/v1/tourney/join", null, u.token)).status, 200);
		const reg = await call("GET", "/v1/tourney", null, users[0].token);
		assert.equal(reg.data.count, 5);
		assert.equal(reg.data.registered, true);
		// Maju ke hari Minggu.
		let day = (Math.floor(1_700_000_000_000 / 86400000) + 3) % 7;
		tick(((6 - day + 7) % 7) * 86400000);
		assert.equal((await call("POST", "/v1/tourney/join", null, users[0].token)).status, 400, "pendaftaran tutup");
		const res = await call("GET", "/v1/tourney", null, users[4].token);
		assert.equal(res.data.phase, "done");
		assert.equal(res.data.rounds, 3, "5 peserta = bagan 8 (3 babak)");
		assert.ok(res.data.my_wins >= 1, "unggulan teratas mendapat bye");
		const again = await call("GET", "/v1/tourney", null, users[2].token);
		assert.deepEqual(again.data.bracket, res.data.bracket, "bagan tetap");
		const champ = res.data.bracket.champion;
		const champWins = (await call("GET", "/v1/tourney", null, users.find((u) => u.player.id === champ).token)).data.my_wins;
		assert.equal(champWins, 3, "juara menang semua babak");
		tick(86400000);
		const next = await call("GET", "/v1/tourney", null, users[4].token);
		assert.equal(next.data.phase, "register");
		assert.equal(next.data.last_wins, res.data.my_wins, "hasil minggu lalu untuk hadiah");
	} finally { server.close(); }
});

test("kotak surat: semua pemain, pribadi, klaim sekali, kedaluwarsa", async () => {
	const { server, call, tick } = await start();
	const { addMail } = require("./server.js");
	try {
		const a = await login(call, "surat-a", "Arya");
		const b = await login(call, "surat-b", "Bayu");
		const t0 = 1_700_000_000_000;
		addMail(server.db, "*", "Kompensasi", "Maaf atas gangguan server.", { gold: 5000, items: { star_stone: 1 } }, 7, t0);
		addMail(server.db, a.player.id, "Untuk Arya", "Hadiah khusus.", { silver: 100 }, 1, t0);
		const la = await call("GET", "/v1/mail", null, a.token);
		assert.equal(la.data.mail.length, 2);
		assert.equal(la.data.mail[1].reward.gold, 1000, "hadiah dibatasi");
		const lb = await call("GET", "/v1/mail", null, b.token);
		assert.equal(lb.data.mail.length, 1, "surat pribadi tidak terlihat pemain lain");
		const id = lb.data.mail[0].id;
		assert.equal((await call("POST", "/v1/mail/claim", { id }, b.token)).status, 200);
		assert.equal((await call("POST", "/v1/mail/claim", { id }, b.token)).status, 409, "klaim sekali");
		assert.equal((await call("GET", "/v1/mail", null, b.token)).data.mail[0].claimed, true);
		const priv = la.data.mail[0].id;
		assert.equal((await call("POST", "/v1/mail/claim", { id: priv }, b.token)).status, 404, "bukan suratnya");
		tick(2 * 86400000);
		assert.equal((await call("GET", "/v1/mail", null, a.token)).data.mail.length, 1, "surat kedaluwarsa hilang");
	} finally { server.close(); }
});

test("statistik anonim: tanpa token, dibersihkan, satu per hari", async () => {
	const { server, call } = await start();
	try {
		assert.equal((await call("POST", "/v1/stats", { install: "pendek" })).status, 400);
		const body = { install: "abcdef0123456789abcd", version: "0.1.0", sessions: 5, play_seconds: 1200, stage: 12,
			tutorial_done: true, events: { hunt: 3, "Bad Key!": 9, win: 12 }, email: "rahasia@contoh.id" };
		assert.equal((await call("POST", "/v1/stats", body)).status, 200);
		await call("POST", "/v1/stats", { ...body, sessions: 6 });
		const rows = server.db.prepare("SELECT * FROM stats_reports").all();
		assert.equal(rows.length, 1, "satu laporan per hari");
		const p = JSON.parse(rows[0].payload);
		assert.equal(p.sessions, 6);
		assert.deepEqual(p.events, { hunt: 3, win: 12 }, "kejadian tak dikenal dibuang");
		assert.equal(p.email, undefined, "kolom asing dibuang");
	} finally { server.close(); }
});


test("undang teman: hadiah lewat surat saat yang diundang mencapai tahap 10", async () => {
	const { server, call, tick } = await start();
	try {
		const a = await login(call, "undang-a", "Arya");
		tick(1000);
		const b = await login(call, "undang-b", "Bayu");
		const code = a.player.code;
		assert.equal((await call("POST", "/v1/referral", { code: b.player.code }, b.token)).status, 400, "kode sendiri");
		assert.equal((await call("POST", "/v1/referral", { code: b.player.code }, a.token)).status, 400, "pengundang lebih baru");
		assert.equal((await call("POST", "/v1/referral", { code: "00000000" }, b.token)).status, 404);
		assert.equal((await call("POST", "/v1/referral", { code }, b.token)).status, 200);
		assert.equal((await call("POST", "/v1/referral", { code }, b.token)).status, 409, "sekali saja");
		assert.equal((await call("GET", "/v1/mail", null, a.token)).data.mail.length, 0, "belum tahap 10");
		await call("POST", "/v1/profile", { stage: 10, power: 50 }, b.token);
		const ma = (await call("GET", "/v1/mail", null, a.token)).data.mail;
		const mb = (await call("GET", "/v1/mail", null, b.token)).data.mail;
		assert.equal(ma.length, 1);
		assert.equal(mb.length, 1);
		assert.equal(ma[0].reward.gold, 100);
		await call("POST", "/v1/profile", { stage: 11 }, b.token);
		assert.equal((await call("GET", "/v1/mail", null, a.token)).data.mail.length, 1, "hadiah tidak dobel");
		const info = (await call("GET", "/v1/referral", null, a.token)).data;
		assert.equal(info.invited, 1);
		assert.equal(info.rewarded, 1);
		const c = await login(call, "undang-c", "Citra");
		tick(8 * 86400000);
		assert.equal((await call("POST", "/v1/referral", { code }, c.token)).status, 400, "akun lama tidak bisa");
	} finally { server.close(); }
});

test("musim aliansi: poin dari perang wilayah & bos, hadiah 3 besar sekali", async () => {
	const { server, call, tick } = await start();
	try {
		const a = await login(call, "musim-a", "Arya");
		const b = await login(call, "musim-b", "Bayu");
		await call("POST", "/v1/profile", { power: 10000, alliance: "garuda" }, a.token);
		await call("POST", "/v1/profile", { power: 100, alliance: "macan" }, b.token);
		await call("POST", "/v1/guildwar/attack", { territory: 0 }, a.token);
		await call("POST", "/v1/worldboss/attack", {}, a.token);
		await call("POST", "/v1/guildwar/attack", { territory: 0 }, b.token);
		const s = (await call("GET", "/v1/season", null, a.token)).data;
		assert.equal(s.board[0].alliance, "garuda");
		assert.ok(s.board[0].points > s.board[1].points);
		assert.equal((await call("POST", "/v1/season/claim", {}, a.token)).status, 400, "musim belum selesai");
		tick(s.ends_in + 1000);
		const s2 = (await call("GET", "/v1/season", null, a.token)).data;
		assert.equal(s2.last_rank, 1);
		const claim = await call("POST", "/v1/season/claim", {}, a.token);
		assert.equal(claim.status, 200);
		assert.equal(claim.data.frame, "frame_juara_musim");
		assert.equal((await call("POST", "/v1/season/claim", {}, a.token)).status, 409);
		assert.equal((await call("POST", "/v1/season/claim", {}, b.token)).data.frame, "frame_musim", "peringkat 2");
	} finally { server.close(); }
});

test("pasar: jual, beli, pajak lewat surat, batal, kedaluwarsa, batas harian", async () => {
	const { server, call, tick } = await start();
	try {
		const a = await login(call, "pasar-a", "Arya");
		const b = await login(call, "pasar-b", "Bayu");
		await call("POST", "/v1/save", { save: { inventory: { star_stone: 5, energy_tea: 10 } } }, a.token);
		assert.equal((await call("POST", "/v1/market/sell", { item: "palsu", qty: 1, price: 10 }, a.token)).status, 400);
		assert.equal((await call("POST", "/v1/market/sell", { item: "star_stone", qty: 0, price: 10 }, a.token)).status, 400);
		const s1 = await call("POST", "/v1/market/sell", { item: "star_stone", qty: 2, price: 1000 }, a.token);
		assert.equal(s1.status, 200);
		const list = (await call("GET", "/v1/market", null, b.token)).data;
		assert.equal(list.listings.length, 1);
		assert.equal(list.listings[0].seller, undefined, "ID penjual tidak dibocorkan");
		assert.equal((await call("POST", "/v1/market/buy", { id: s1.data.id }, a.token)).status, 400, "beli sendiri");
		const buy = await call("POST", "/v1/market/buy", { id: s1.data.id }, b.token);
		assert.deepEqual(buy.data, { item: "star_stone", qty: 2, price: 1000 });
		assert.equal((await call("POST", "/v1/market/buy", { id: s1.data.id }, b.token)).status, 404, "sudah terjual");
		const mail = (await call("GET", "/v1/mail", null, a.token)).data.mail;
		assert.equal(mail[0].reward.silver, 900, "hasil dikurangi pajak 10%");
		const notices = (await call("GET", "/v1/notices?since=0", null, a.token)).data;
		assert.equal(notices.sold, 1);
		assert.equal(notices.mail, 1);
		const s2 = await call("POST", "/v1/market/sell", { item: "energy_tea", qty: 1, price: 5 }, a.token);
		assert.equal((await call("POST", "/v1/market/cancel", { id: s2.data.id }, b.token)).status, 404, "bukan miliknya");
		assert.equal((await call("POST", "/v1/market/cancel", { id: s2.data.id }, a.token)).status, 200);
		const s3 = await call("POST", "/v1/market/sell", { item: "energy_tea", qty: 1, price: 5 }, a.token);
		for (let i = 0; i < 2; i++) await call("POST", "/v1/market/sell", { item: "energy_tea", qty: 1, price: 5 }, a.token);
		assert.equal((await call("POST", "/v1/market/sell", { item: "energy_tea", qty: 1, price: 5 }, a.token)).status, 429);
		tick(4 * 86400000);
		await call("GET", "/v1/market", null, b.token);
		const back = (await call("GET", "/v1/mail", null, a.token)).data.mail.filter((m) => m.title === "Dagangan Kembali");
		assert.equal(back.length, 3, "dagangan kedaluwarsa dikembalikan");
		assert.equal((await call("POST", "/v1/market/buy", { id: s3.data.id }, b.token)).status, 404);
	} finally { server.close(); }
});

test("dasbor admin: halaman terbuka, API butuh token", async () => {
	const { server, call } = await start({ adminToken: "rahasia-admin" });
	try {
		const page = await call("GET", "/admin");
		assert.equal(page.status, 200);
		assert.match(page.type, /text\/html/);
		assert.equal((await call("GET", "/admin/api/overview")).status, 401);
		assert.equal((await call("GET", "/admin/api/overview", null, null, { "X-Admin-Token": "salah" })).status, 401);
		const H = { "X-Admin-Token": "rahasia-admin" };
		await login(call, "admin-a", "Arya");
		assert.equal((await call("GET", "/admin/api/overview", null, null, H)).data.players, 1);
		assert.equal((await call("POST", "/admin/api/mail", { to: "all", title: "Halo", body: "Isi", reward: { gold: 5 } }, null, H)).status, 200);
		assert.equal((await call("POST", "/admin/api/codes", { code: "ujicoba", reward: { gold: 1 } }, null, H)).data.code, "UJICOBA");
		assert.equal((await call("GET", "/admin/api/codes", null, null, H)).data.codes.length, 1);
		assert.ok(Array.isArray((await call("GET", "/admin/api/stats?days=7", null, null, H)).data.days));
		assert.ok(Array.isArray((await call("GET", "/admin/api/reports", null, null, H)).data.reports));
	} finally { server.close(); }
	const off = await start({ adminToken: "" });
	try {
		assert.equal((await off.call("GET", "/admin/api/overview", null, null, { "X-Admin-Token": "" })).status, 403);
	} finally { off.server.close(); }
});

test("verifikasi pembelian Google Play (dengan Google tiruan)", async () => {
	const { privateKey } = require("node:crypto").generateKeyPairSync("rsa", { modulusLength: 2048,
		privateKeyEncoding: { type: "pkcs8", format: "pem" }, publicKeyEncoding: { type: "spki", format: "pem" } });
	const calls = [];
	const fakeFetch = async (url, init) => {
		calls.push(url);
		if (url.includes("oauth2")) {
			assert.match(init.body, /assertion=/);
			return { ok: true, status: 200, json: async () => ({ access_token: "akses", expires_in: 3600 }) };
		}
		const token = decodeURIComponent(url.split("/tokens/")[1]);
		if (token === "token-palsu-xyz") return { ok: false, status: 400, json: async () => ({}) };
		return { ok: true, status: 200, json: async () => ({ purchaseState: token === "token-batal-xyz" ? 1 : 0, orderId: "GPA.1" }) };
	};
	const { server, call } = await start({ iap: { packageName: "com.microaltech.tuannusantara",
		serviceAccount: { client_email: "uji@x.iam.gserviceaccount.com", private_key: privateKey }, fetch: fakeFetch } });
	try {
		const a = await login(call, "iap-a", "Arya");
		const b = await login(call, "iap-b", "Bayu");
		const ok = await call("POST", "/v1/iap/verify", { product: "gold_60", token: "token-asli-12345" }, a.token);
		assert.equal(ok.status, 200);
		assert.equal(ok.data.valid, true);
		assert.equal((await call("POST", "/v1/iap/verify", { product: "gold_60", token: "token-asli-12345" }, a.token)).data.repeat, true);
		assert.equal((await call("POST", "/v1/iap/verify", { product: "gold_60", token: "token-asli-12345" }, b.token)).status, 409);
		assert.equal((await call("POST", "/v1/iap/verify", { product: "gold_60", token: "token-palsu-xyz" }, a.token)).status, 402);
		assert.equal((await call("POST", "/v1/iap/verify", { product: "gold_60", token: "token-batal-xyz" }, a.token)).status, 402);
		assert.equal(calls.filter((u) => u.includes("oauth2")).length, 1, "token akses disimpan");
	} finally { server.close(); }
	const off = await start();
	try {
		const a = await login(off.call, "iap-c", "Citra");
		const r = await off.call("POST", "/v1/iap/verify", { product: "gold_60", token: "token-asli-12345" }, a.token);
		assert.equal(r.status, 503);
		assert.equal(r.data.disabled, true);
	} finally { off.server.close(); }
});

test("save di server: simpan, ambil, tanda emas mencurigakan, pasar memakai inventaris server", async () => {
	const { server, call, tick } = await start({ adminToken: "adm" });
	try {
		const a = await login(call, "save-a", "Arya");
		const b = await login(call, "save-b", "Bayu");
		assert.equal((await call("GET", "/v1/save", null, a.token)).status, 404);
		assert.equal((await call("POST", "/v1/market/sell", { item: "star_stone", qty: 1, price: 5 }, a.token)).status, 409,
			"tanpa save server tidak bisa jual");
		const save = { version: 5, gold: 100, silver: 5000, inventory: { star_stone: 2, "Bad!": 3 } };
		assert.equal((await call("POST", "/v1/save", { save, version: "0.1.0" }, a.token)).status, 200);
		const got = await call("GET", "/v1/save", null, a.token);
		assert.equal(got.data.save.gold, 100);
		assert.equal((await call("POST", "/v1/market/sell", { item: "star_stone", qty: 3, price: 5 }, a.token)).status, 409,
			"tidak bisa jual melebihi save server");
		assert.equal((await call("POST", "/v1/market/sell", { item: "star_stone", qty: 2, price: 5 }, a.token)).status, 200);
		assert.equal((await call("POST", "/v1/market/sell", { item: "star_stone", qty: 1, price: 5 }, a.token)).status, 409,
			"item yang sudah dijual tidak bisa dijual lagi");
		tick(3600000);
		await call("POST", "/v1/save", { save: { ...save, gold: 999999 } }, a.token);
		await call("POST", "/v1/save", { save: { gold: 50 } }, b.token);
		const flags = (await call("GET", "/admin/api/flags", null, null, { "X-Admin-Token": "adm" })).data.flags;
		assert.equal(flags.length, 1, "lonjakan emas ditandai");
		assert.equal(flags[0].name, "Arya");
		const big = { blob: "x".repeat(700 * 1024) };
		assert.equal((await call("POST", "/v1/save", { save: big }, a.token)).status, 413);
	} finally { server.close(); }
});

test("pindah perangkat: kode sekali pakai memindahkan akun dan save", async () => {
	const { server, call, tick } = await start();
	try {
		const a = await login(call, "lama-hp-a", "Arya");
		await call("POST", "/v1/save", { save: { gold: 77 } }, a.token);
		const tr = await call("POST", "/v1/account/transfer", {}, a.token);
		assert.match(tr.data.code, /^[A-Z2-9]{8}$/);
		// HP baru sempat membuat akun kosong otomatis.
		const fresh = await login(call, "baru-hp-b", "Tuan");
		assert.equal((await call("POST", "/v1/account/claim", { code: "SALAHSAL", device_id: "baru-hp-bxxxxxxxx" })).status, 404);
		const cl = await call("POST", "/v1/account/claim", { code: tr.data.code.toLowerCase(), device_id: "baru-hp-b".padEnd(16, "x") });
		assert.equal(cl.status, 200);
		assert.equal(cl.data.player.id, a.player.id);
		assert.equal(cl.data.save.gold, 77);
		assert.equal((await call("GET", "/v1/save", null, a.token)).status, 401, "token lama tidak berlaku");
		assert.equal((await call("GET", "/v1/save", null, cl.data.token)).status, 200);
		const again = await login(call, "baru-hp-b", "Tuan");
		assert.equal(again.player.id, a.player.id, "HP baru kini masuk ke akun lama");
		assert.notEqual(fresh.player.id, a.player.id);
		assert.equal((await call("POST", "/v1/account/claim", { code: tr.data.code, device_id: "lain-hp-cxxxxxxxx" })).status, 404,
			"kode sekali pakai");
		const tr2 = await call("POST", "/v1/account/transfer", {}, cl.data.token);
		tick(25 * 3600000);
		assert.equal((await call("POST", "/v1/account/claim", { code: tr2.data.code, device_id: "lain-hp-cxxxxxxxx" })).status, 404,
			"kode kedaluwarsa");
	} finally { server.close(); }
});

test("konfigurasi jarak jauh dan laporan crash", async () => {
	const { server, call } = await start({ adminToken: "adm" });
	try {
		const H = { "X-Admin-Token": "adm" };
		const def = (await call("GET", "/v1/config")).data;
		assert.equal(def.yield_bonus, 0);
		assert.equal(def.announcement, null);
		await call("POST", "/admin/api/config", { yield_bonus: 5, gacha_discount: 0.2, rateup: "Satria!", min_version: 3,
			announcement: { id: "a1", title: "Halo", body: "Akhir pekan ganda!" }, palsu: 1 }, null, H);
		const c = (await call("GET", "/v1/config")).data;
		assert.equal(c.yield_bonus, 1, "dibatasi");
		assert.equal(c.gacha_discount, 0.2);
		assert.equal(c.rateup, "satria");
		assert.equal(c.min_version, 3);
		assert.equal(c.announcement.title, "Halo");
		assert.equal(c.palsu, undefined);
		assert.equal((await call("POST", "/v1/crash", { install: "pendek" })).status, 400);
		const rep = { install: "abcdef0123456789abcd", version: "0.1.0", device: "SM-A105F", gpu: "Mali-G71", report: "log" };
		assert.equal((await call("POST", "/v1/crash", rep)).status, 200);
		await call("POST", "/v1/crash", rep);
		const cr = (await call("GET", "/admin/api/crashes", null, null, H)).data;
		assert.equal(cr.groups[0].n, 2);
		assert.equal(cr.groups[0].device, "SM-A105F");
	} finally { server.close(); }
});

test("umpan balik: teks + gambar, balasan admin lewat surat", async () => {
	const { server, call } = await start({ adminToken: "adm" });
	try {
		const H = { "X-Admin-Token": "adm" };
		const a = await login(call, "umpan-a", "Arya");
		assert.equal((await call("POST", "/v1/feedback", { text: "x" }, a.token)).status, 400);
		const jpg = Buffer.concat([Buffer.from([0xff, 0xd8, 0xff, 0xe0]), Buffer.alloc(100 * 1024, 1)]).toString("base64");
		assert.equal((await call("POST", "/v1/feedback", { kind: "bug", text: "Tombol terpotong di halaman Istana",
			screenshot: jpg, version: "0.1.0", device: "SM-A105F", lang: "id" }, a.token)).status, 200, "kiriman ~136 KB diterima");
		await call("POST", "/v1/feedback", { kind: "saran", text: "Tambah kuda putih", screenshot: "bukan-gambar" }, a.token);
		const list = (await call("GET", "/admin/api/feedback", null, null, H)).data.feedback;
		assert.equal(list.length, 2);
		assert.equal(list[1].has_shot, true);
		assert.equal(list[0].has_shot, false, "data bukan gambar dibuang");
		const shot = await call("GET", `/admin/api/feedback/shot?id=${list[1].id}`, null, null, H);
		assert.match(shot.type, /image\/jpeg/);
		await call("POST", "/admin/api/feedback/reply", { id: list[1].id, text: "Terima kasih, sudah diperbaiki!",
			reward: { gold: 20 } }, null, H);
		const mail = (await call("GET", "/v1/mail", null, a.token)).data.mail;
		assert.equal(mail[0].title, "Balasan Pengembang");
		assert.equal(mail[0].reward.gold, 20);
		for (let i = 0; i < 3; i++) await call("POST", "/v1/feedback", { text: "laporan lagi" }, a.token);
		assert.equal((await call("POST", "/v1/feedback", { text: "laporan lagi" }, a.token)).status, 429, "batas harian");
	} finally { server.close(); }
});

test("jadwal acara dan eksperimen A/B di konfigurasi", async () => {
	const { server, call, tick, now } = await start({ adminToken: "adm" });
	try {
		const H = { "X-Admin-Token": "adm" };
		const iso = (ms) => new Date(ms).toISOString();
		const r = await call("POST", "/admin/api/schedule", { title: "HUT RI", start: iso(now() + 3600000),
			end: iso(now() + 3 * 86400000), overrides: { yield_bonus: 0.5, palsu: 1,
				announcement: { id: "hutri", title: "Dirgahayu RI", body: "Bonus +50%!" } } }, null, H);
		assert.equal(r.status, 200);
		assert.equal(r.data.overrides.palsu, undefined);
		assert.equal((await call("GET", "/v1/config")).data.yield_bonus, 0, "belum mulai");
		tick(2 * 3600000);
		const c = (await call("GET", "/v1/config")).data;
		assert.equal(c.yield_bonus, 0.5, "acara aktif");
		assert.equal(c.announcement.id, "hutri");
		tick(3 * 86400000);
		assert.equal((await call("GET", "/v1/config")).data.yield_bonus, 0, "acara selesai");
		assert.equal((await call("POST", "/admin/api/schedule", { start: "x", end: "y", overrides: { yield_bonus: 1 } },
			null, H)).status, 400);
		await call("POST", "/admin/api/config", { experiments: [{ id: "Diskon Rekrut", variants: [
			{ name: "a", overrides: {} }, { name: "b", overrides: { gacha_discount: 0.9, palsu: 3 } }] }, { id: "satu", variants: [] }] },
		null, H);
		const exps = (await call("GET", "/v1/config")).data.experiments;
		assert.equal(exps.length, 1, "eksperimen tanpa 2 varian dibuang");
		assert.equal(exps[0].id, "diskonrekrut");
		assert.equal(exps[0].variants[1].overrides.gacha_discount, 0.5, "dibatasi");
		for (const [i, g] of [["abcdef0123456789aaaa", "a"], ["abcdef0123456789bbbb", "b"]]) {
			await call("POST", "/v1/stats", { install: i, sessions: 1, play_seconds: 600, groups: { diskonrekrut: g } });
		}
		const st = (await call("GET", "/admin/api/stats?days=7", null, null, H)).data;
		assert.equal(st.experiments.diskonrekrut.a.installs, 1);
		assert.equal(st.experiments.diskonrekrut.b.minutes, 10);
	} finally { server.close(); }
});

test("raid aliansi: serang bergiliran, hadiah menurut kontribusi, sekali", async () => {
	const { server, call, tick } = await start();
	try {
		const a = await login(call, "raid-a", "Arya");
		const b = await login(call, "raid-b", "Bayu");
		const c = await login(call, "raid-c", "Citra");
		await call("POST", "/v1/profile", { power: 400000, alliance: "garuda" }, a.token);
		await call("POST", "/v1/profile", { power: 10000, alliance: "garuda" }, b.token);
		assert.equal((await call("GET", "/v1/raid", null, c.token)).status, 400, "tanpa aliansi");
		const r0 = (await call("GET", "/v1/raid", null, a.token)).data;
		assert.equal(r0.hp_max, 410000 * 3);
		assert.equal(r0.attacks_left, 2);
		await call("POST", "/v1/raid/attack", {}, a.token);
		await call("POST", "/v1/raid/attack", {}, a.token);
		assert.equal((await call("POST", "/v1/raid/attack", {}, a.token)).status, 429);
		await call("POST", "/v1/raid/attack", {}, b.token);
		tick(86400000);
		await call("POST", "/v1/raid/attack", {}, a.token);
		await call("POST", "/v1/raid/attack", {}, a.token);
		const r1 = (await call("GET", "/v1/raid", null, a.token)).data;
		assert.ok(r1.damage >= r1.hp_max, "benteng runtuh");
		assert.equal((await call("POST", "/v1/raid/attack", {}, b.token)).status, 409);
		assert.equal((await call("POST", "/v1/raid/claim", {}, a.token)).status, 400, "raid belum selesai");
		tick(r1.ends_in + 1000);
		const ca = await call("POST", "/v1/raid/claim", {}, a.token);
		const cb = await call("POST", "/v1/raid/claim", {}, b.token);
		assert.equal(ca.data.reward.gold, 150, "kontributor besar");
		assert.equal(cb.data.reward.gold, 40, "kontributor kecil");
		assert.equal((await call("POST", "/v1/raid/claim", {}, a.token)).status, 409);
	} finally { server.close(); }
});

test("status server dan cadangan database", async () => {
	const os = require("node:os");
	const fsx = require("node:fs");
	const dir = fsx.mkdtempSync(require("node:path").join(os.tmpdir(), "tlg-backup-"));
	const { server, call } = await start({ adminToken: "adm", backupDir: dir });
	try {
		const st = (await call("GET", "/status")).data;
		assert.equal(st.ok, true);
		assert.ok(st.last_backup.file.startsWith("tlg-"));
		assert.equal(fsx.readdirSync(dir).length, 1, "cadangan dibuat saat server mulai");
		assert.equal((await call("POST", "/admin/api/backup", {}, null, { "X-Admin-Token": "adm" })).status, 200);
	} finally { server.close(); fsx.rmSync(dir, { recursive: true, force: true }); }
});
