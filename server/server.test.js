// Tes server: node --test server/
"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { createServer } = require("./server.js");

async function start(opts = {}) {
	let t = 1_700_000_000_000;
	const server = createServer({ now: () => t, random: opts.random || (() => 0.5) });
	await new Promise((r) => server.listen(0, r));
	const base = `http://127.0.0.1:${server.address().port}`;
	const call = async (method, path, body, token) => {
		const res = await fetch(base + path, {
			method, body: body ? JSON.stringify(body) : undefined,
			headers: token ? { Authorization: `Bearer ${token}` } : {},
		});
		return { status: res.status, data: await res.json() };
	};
	return { server, call, tick: (ms) => { t += ms; } };
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
