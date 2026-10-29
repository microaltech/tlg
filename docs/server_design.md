# Rancangan Server Online

> **Status:** tahap pertama sudah diimplementasikan di `server/` (Node.js + SQLite):
> akun perangkat, profil, papan peringkat, chat aliansi dengan lapor/blokir, dan arena
> melawan pemain sungguhan (hasil dihitung server). Klien: autoload `Online`
> (`scripts/core/online.gd`). Ekonomi, aliansi dinamis, bos, dan perang di bawah ini
> masih rencana; Nakama tetap rekomendasi bila fitur-fitur itu dipindahkan ke server.

Saat ini Top Lord Like berjalan sepenuhnya offline. Aliansi, chat, arena, perang
guild, bos, dan peringkat adalah simulasi NPC yang deterministik di
`game_model.gd`. Dokumen ini merancang cara menggantinya dengan server sungguhan
tanpa menulis ulang game.

## 1. Tujuan dan prinsip

1. **Server memegang kebenaran** untuk semua yang bernilai, yaitu emas, gacha,
   pembelian, hadiah, dan peringkat. Klien hanya menampilkan data dan mengirim
   *perintah*, bukan *hasil*.
2. **Waktu server** dipakai untuk semua timer: charge, reset harian/mingguan,
   rekrut gratis, dan jeda anak. Mengubah jam HP tidak boleh menguntungkan
   pemain.
3. **Tetap terasa instan.** Aksi kota cukup sering dilakukan, sehingga klien
   memprediksi hasilnya secara lokal (logika di `GameModel` tetap dipakai), lalu
   menyamakannya dengan respons server.
4. **Migrasi bertahap.** Fitur sosial dipindah lebih dulu, karena simulasinya
   paling terasa "palsu". Ekonomi pribadi menyusul.

## 2. Pilihan teknologi

| Opsi | Kelebihan | Kekurangan | Rekomendasi |
|---|---|---|---|
| **Nakama** (Heroic Labs, open source) | SDK Godot 4 resmi; sudah punya akun, storage, leaderboard, grup (aliansi), chat realtime, notifikasi, dan validasi IAP Google; logika server ditulis dalam Go/TypeScript/Lua | Perlu belajar model Nakama; skala besar butuh Heroic Cloud atau ops sendiri | **Dipilih** untuk tim kecil |
| Go/Node + PostgreSQL + Redis (buatan sendiri) | Kendali penuh | Semua fitur di atas harus dibuat sendiri | Bila tim backend sudah ada |
| Firebase (Auth + Firestore + Functions) | Cepat untuk prototipe | Leaderboard & chat skala besar mahal/repot; logika transaksi rumit | Tidak disarankan untuk SLG |

Topologi awal (Nakama):

```
HP (Godot) ──HTTPS/WebSocket──▶ Nakama (2+ node) ──▶ PostgreSQL / CockroachDB
                                  │  runtime modul Go: ekonomi, gacha, aliansi, arena, perang
                                  ├─▶ Google Play Developer API (validasi pembelian)
                                  └─▶ FCM (push: bos muncul, perang dimulai, diserang di arena)
```

## 3. Akun dan migrasi save lokal

- Login pertama memakai **device auth** (ID perangkat acak yang disimpan di
  `user://`), jadi pemain tidak perlu mendaftar. Akun bisa ditautkan ke
  **Google Play Games** agar progres tidak hilang saat ganti HP.
- **Migrasi sekali jalan**: klien mengunggah `save.json`. Server memvalidasi
  batas wajar sebelum menerima: tahap ≤ batas kurva, jumlah penasihat ≤ katalog,
  bintang ≤ 5, sumber daya ≤ hasil maksimum teoretis sejak `start_day`, dan
  emas ≤ total hadiah yang mungkin + pembelian terverifikasi. Kelebihan
  dipangkas. Setelah migrasi, save lokal hanya berfungsi sebagai cache.
- Nama Tuan (`lord_name`) menjadi nama tampilan unik per server, dengan filter
  kata kasar dan rate limit untuk penggantian.

## 4. Peta fitur: dari simulasi ke server

Fungsi yang menyimulasikan pemain lain sengaja dikumpulkan di satu tempat. Itulah
"sambungan" (*seam*) yang akan diganti dengan panggilan server.

| Fitur | Simulasi sekarang (`game_model.gd`) | Di server |
|---|---|---|
| Anggota aliansi | `_npc_members`, `_npc_power`, `alliance_members` | **Grup Nakama** (maks. 30 anggota) + metadata aliansi: level, exp, log. Peran: Ketua, Wakil, Anggota |
| Sumbangan & toko aliansi | `donate`, `shop_buy` | RPC `alliance_donate` / `alliance_shop_buy` dengan limit harian dari waktu server; exp aliansi diubah secara atomik |
| Bos mingguan | `_npc_boss_damage_each`, `boss_info`, `attack_boss` | HP bos tersimpan per aliansi per minggu. `attack_boss` menghitung damage di server dari kekuatan tempur tersimpan; hadiah dibagi saat bos kalah (job terjadwal) |
| Chat aliansi | `chat_messages`, `chat_send`, `_chat_npc_reply`, `_chat_catch_up` | **Channel chat grup** Nakama (realtime WebSocket, riwayat 100 pesan). Filter kata kasar dan rate limit 1 pesan/2 detik. Pesan sistem (bos kalah, perang) dikirim oleh modul server |
| Arena | `ensure_arena` (lawan NPC), `arena_fight`, rating Elo | **PvP asinkron**: setiap pemain punya *snapshot pertahanan* (penasihat + kekuatan tempur) yang diperbarui saat ia bermain. Matchmaking memilih 3 lawan dengan rating ±150. Pertarungan dihitung di server dengan RNG server, dan yang diserang mendapat log + push |
| Musim arena & toko | `claim_arena_season`, `arena_shop_buy` | Leaderboard Nakama yang di-reset mingguan; hadiah musim dibagikan oleh job reset |
| Perang guild | `ensure_war`, `_war_simulate_until`, `_side_power`, `attack_fort` | Pasangan aliansi dipilih tiap Senin berdasarkan kekuatan total. HP benteng tersimpan di server; serangan anggota mengurangi HP secara atomik; hasil dihitung saat perang ditutup (Minggu 23.59 waktu server) |
| Peringkat global | `lb_rank`, `lb_top`, `lb_alliances` (distribusi statistik) | **Leaderboard Nakama**: kekuatan, kampanye, prestise, arena, aliansi. Skor *dihitung server* dari state pemain, bukan dikirim klien. Hadiah mingguan dibagikan oleh job reset |
| Perjamuan (undangan) | `banquet_invites` (host NPC) | Perjamuan yang diadakan anggota aliansi tampil sebagai undangan sungguhan. Tamu menambah prestise tuan rumah |
| Pembelian | `Store` → `grant_purchase` | Klien mengirim token pembelian. Server memvalidasi ke Google Play Developer API, mencatat token (idempoten), memberi isi produk, lalu klien memanggil `acknowledge`/`consume` setelah server sukses. Notifikasi RTDN (Pub/Sub) menangani refund |
| Gacha | `recruit`, `_roll_rarity` | **RNG hanya di server.** Pity disimpan server. Riwayat tarikan bisa dilihat pemain (transparansi peluang) |
| Ekonomi pribadi (kota, penasihat, kampanye, istana) | Semua fungsi lain | Fase 3: RPC per aksi dengan validasi charge dari waktu server. Klien memprediksi hasil memakai `GameModel` yang sama, sehingga rumus harus identik (lihat §6) |

## 5. Model data (ringkas)

Disimpan sebagai *storage object* Nakama atau tabel SQL:

```
player_state   (user_id PK, version, json state seperti to_dict(), updated_at)
wallet         (user_id, gold, silver, grain, soldiers)      -- ledger Nakama, setiap perubahan tercatat
purchases      (token PK, user_id, product_id, state, granted_at, refunded_at)
gacha_log      (id, user_id, t, results json, pity_after)
alliance       (id PK, name, emblem, level, exp, week, boss_hp, boss_damage json)
alliance_log   (alliance_id, t, text)
arena_defense  (user_id PK, rating, power, lineup json, updated_at)
arena_log      (id, attacker, defender, t, win, delta)
war            (week, alliance_a, alliance_b, forts_a json, forts_b json, result)
leaderboard_*  (Nakama leaderboard: power, stage, prestige, arena, alliance)
```

`player_state` menyimpan dokumen yang sama dengan `GameModel.to_dict()`, sehingga
`from_dict` di klien bisa langsung memuat respons server. Field `version` dipakai
untuk *optimistic locking*: aksi dengan versi lama ditolak, lalu klien memuat
ulang.

## 6. Satu sumber rumus

Rumus ekonomi saat ini ada di GDScript (`game_data.gd` dan `game_model.gd`).
Pilihan untuk server:

1. **Port ke Go** di modul Nakama. Konstanta diekspor dari `game_data.gd` ke
   JSON saat build, lalu dibaca kedua sisi. Tes kesetaraan menjalankan skenario
   yang sama di GDScript (`tests/run_tests.gd`) dan Go, lalu membandingkan
   hasilnya.
2. Menjalankan **Godot headless sebagai server logika** (lebih mudah, tetapi
   lebih berat dan sulit diskalakan). Cocok untuk prototipe internal saja.

Rekomendasi: opsi 1. Bot `tools/sim_economy.gd` bisa dipakai juga sebagai
*load test* dan pemeriksa keseimbangan di server staging.

## 7. Protokol klien

- **RPC (HTTPS)** untuk aksi: `affair`, `upgrade`, `fight_stage`, `recruit`,
  `claim_*`, `alliance_*`, `arena_fight`, `war_attack`. Respons berisi
  `{ok, msg, state_patch, version}`.
- **WebSocket** untuk chat, kehadiran anggota, notifikasi in-game (bos kalah,
  diserang di arena), dan dorongan *state_patch* dari job server.
- **Offline**: aksi sosial dinonaktifkan dengan pesan yang jelas. Aksi kota
  boleh diantrekan maksimal beberapa menit, lalu divalidasi ulang oleh server
  saat online. Aksi yang tidak lolos (mis. charge tidak cukup) dibatalkan.
- Ringkasan "Selamat datang kembali" (`away_report`) bisa dihasilkan server dari
  event yang terjadi selama pemain offline, yang hasilnya lebih kaya daripada
  versi lokal.

## 8. Anti-curang

- Semua timer memakai waktu server. Klien mengirim aksi, bukan timestamp.
- Server menghitung hasil dan skor. Klien tidak pernah mengirim "saya dapat X".
- Rate limit per RPC, deteksi anomali (mis. kenaikan kekuatan melebihi batas
  teoretis per jam), dan audit ledger.
- Pembelian divalidasi server dan idempoten per token, lalu refund ditarik lewat
  RTDN.
- Build rilis memakai obfuscation ringan. Keamanan sebenarnya tetap di server.

## 9. Operasional dan biaya kasar

| Tahap | Pemain aktif harian | Infrastruktur | Perkiraan biaya/bulan |
|---|---|---|---|
| Uji tertutup | < 1.000 | 1 VM 2 vCPU (Nakama + Postgres) | US$20–40 |
| Rilis awal | 10.000 | 2 node Nakama + Postgres terkelola + Redis | US$150–400 |
| Tumbuh | 100.000 | Heroic Cloud atau Kubernetes, CockroachDB | US$1.500+ |

- Backup database harian (retensi 30 hari), pemantauan (Prometheus/Grafana
  bawaan Nakama), dan peringatan untuk error rate serta latensi RPC.
- **Server/regional**: mulai dengan satu server global (Asia Tenggara, mis.
  Singapura/Jakarta). Tambahkan "server" (shard) baru saat aliansi dan
  peringkat terasa penuh, mengikuti pola game SLG.

## 10. Dampak privasi

Begitu server aktif, game **mengumpulkan data**: ID akun/perangkat, nama Tuan,
pesan chat, data gameplay, dan riwayat pembelian. Yang harus diperbarui:
`docs/privacy_policy.md`, formulir Data Safety (`docs/play_data_safety.md`),
ringkasan di dalam game (`PRIVACY_SECTIONS`), fitur hapus akun (wajib Google
Play untuk aplikasi yang memiliki akun), serta fitur laporkan/blokir pemain untuk
chat.

## 11. Rencana bertahap

| Fase | Isi | Perkiraan (1–2 developer backend) |
|---|---|---|
| 0. Fondasi | Nakama staging, device auth, unggah/unduh `player_state`, validasi IAP di server | 3–4 minggu |
| 1. Sosial | Aliansi (grup), chat realtime, peringkat global sungguhan | 4–6 minggu |
| 2. Kompetitif | Arena asinkron, bos aliansi bersama, perang guild mingguan, push FCM | 6–8 minggu |
| 3. Ekonomi otoritatif | Semua aksi lewat RPC dengan prediksi klien, gacha di server, migrasi save | 6–8 minggu |
| 4. Live ops | Event dari server (tanpa update aplikasi), konfigurasi angka jarak jauh, dashboard admin, moderasi chat | berkelanjutan |

Setiap fase bisa dirilis sendiri. Fitur yang belum dipindah tetap memakai
simulasi lokal yang ada sekarang.
