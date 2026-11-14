# Server sosial Tuan Nusantara

Server kecil tanpa dependensi luar (Node.js 22.13+, `node:http` dan `node:sqlite`)
untuk fitur sosial dengan pemain sungguhan:

- **Akun perangkat**: ID acak di HP ditukar dengan token (tanpa email/kata sandi).
- **Profil**: nama Tuan, kostum, bingkai, aliansi, kekuatan, tahap, menara, prestise.
- **Papan peringkat** per kategori (`power`, `stage`, `tower`, `prestige`).
- **Chat aliansi**: hanya sesama anggota aliansi; filter kata kasar, jeda 2 detik,
  200 pesan terakhir per aliansi disimpan. Pemain bisa **melaporkan** pesan (pesan
  disembunyikan setelah 3 laporan dari pemain berbeda; laporan tersimpan di tabel
  `reports` untuk ditinjau) dan **memblokir** pemain (pesannya disembunyikan di HP).
- **Arena**: lawan sungguhan dengan poin terdekat. Menang/kalah dan perubahan poin
  (Elo) dihitung server; maks. 20 serangan per 24 jam.
- **Teman & hadiah**: tambah teman dengan kode 8 karakter (dua arah, maks. 50),
  kirim satu hadiah per teman per hari, terima maks. 10 hadiah per hari, dan
  kunjungi kota teman (ringkasan jabatan, bangunan, kapal, besan; angka dibatasi).
- **Raja Hari Ini**: pemain berkekuatan tertinggi yang aktif 3 hari terakhir,
  dikunci saat permintaan pertama hari itu (UTC). Raja memilih satu titah dari
  daftar tetap (tanpa teks bebas) yang memberi bonus kecil untuk semua pemain.
- **Perang Wilayah Aliansi**: tiap minggu (mulai Senin UTC) aliansi memperebutkan
  6 wilayah. Tiap pemain menyerang maks. 3 kali per hari; poin = akar kekuatan x
  0,8–1,2. Aliansi dengan poin terbanyak menguasai wilayah; hadiah minggu lalu
  diambil di game.

- **Bos Dunia**: satu bos per minggu untuk semua pemain (HP = 5x total kekuatan
  pemain aktif seminggu terakhir, min. 200.000). Maks. 3 serangan per hari;
  kerusakan = kekuatan x 0,8–1,2. Peringkat minggu lalu dipakai game untuk hadiah.
- **Kode hadiah**: dibuat pengelola dengan `server/admin.js`, berkuota dan
  berkedaluwarsa, sekali per pemain. Hadiah dibatasi (emas maks. 1.000, sumber
  daya maks. 10 juta, item yang dikenal maks. 10), dan game membatasinya lagi.

### Kode hadiah

```
DB_PATH=server/data/tlg.db node server/admin.js add-code NUSANTARA2026 gold=100 items.recruit_ticket=1 --max 1000 --days 30
DB_PATH=server/data/tlg.db node server/admin.js list-codes
```

### Kotak surat (pengumuman & kompensasi)

```
# untuk semua pemain, berlaku 14 hari
DB_PATH=server/data/tlg.db node server/admin.js send-mail --to all --title "Maaf atas gangguan" \
  --body "Server sempat mati. Terimalah kompensasi ini." gold=100 items.energy_tea=2 --days 14
# untuk satu pemain (kode teman dari halaman Teman)
DB_PATH=server/data/tlg.db node server/admin.js send-mail --to 1a2b3c4d --title "..." --body "..." silver=5000
```

Hadiah surat dibatasi sama seperti kode hadiah, dan tiap surat hanya bisa diambil
sekali per pemain (dicek server).

### Statistik anonim (opt-in)

Pemain yang menyalakan *Bagikan statistik anonim* mengirim satu laporan ringkas per
hari ke `POST /v1/stats` (tanpa token; ID pemasangan acak, hanya angka dan nama aksi
bawaan). Ringkasan harian, retensi H1/H7, dan aksi terpopuler:

```
DB_PATH=server/data/tlg.db node server/admin.js stats 14
```

Statistik juga bisa diarahkan ke server tersendiri tanpa mode online dengan mengisi
`application/config/stats_url` di `project.godot` sebelum build rilis.

### Dasbor admin

Set `ADMIN_TOKEN` (acak, panjang) saat menjalankan server, lalu buka
`https://alamat-server/admin`. Isi token di pojok kanan atas. Dasbor menampilkan
ringkasan pemain, statistik anonim & retensi, musim aliansi, form kirim surat dan
buat kode hadiah, serta laporan chat (sembunyikan/tampilkan pesan). Tanpa
`ADMIN_TOKEN` semua API admin menolak (403).

```
ADMIN_TOKEN=$(openssl rand -hex 24) node server/server.js
```

### Verifikasi pembelian Google Play

1. Play Console → Setup → API access: hubungkan proyek Google Cloud, buat *service
   account*, beri izin "View financial data" untuk aplikasi.
2. Unduh kunci JSON service account ke server (jangan di-commit).
3. Jalankan server dengan:
   `IAP_PACKAGE=com.microaltech.tuannusantara IAP_SERVICE_ACCOUNT=/path/kunci.json`

Game memanggil `POST /v1/iap/verify` sebelum memberi emas. Token pembelian dicatat
sehingga tidak bisa dipakai dua akun. Tanpa konfigurasi server menjawab 503 dan game
memakai cek di perangkat seperti sebelumnya.

### Undang teman, musim aliansi, pasar pemain

- **Undang teman**: pemain baru (≤7 hari) memasukkan kode teman pengundang. Saat
  profilnya melaporkan tahap ≥10, keduanya mendapat 100 emas + 2 Tiket Rekrut lewat
  surat (maks. 20 undangan berhadiah per pengundang).
- **Musim aliansi**: 4 minggu. Poin = poin serangan Perang Wilayah + akar kerusakan
  Bos Dunia. Anggota 3 aliansi teratas mengambil hadiah musim lalu sekali
  (`frame_juara_musim` / `frame_musim`).
- **Pasar pemain**: item dari daftar kode hadiah, maks. 10 per dagangan, harga ≤10 juta
  perak, 5 dagangan per hari, pajak 10%. Hasil penjualan, dagangan yang ditarik, dan
  yang tidak laku 3 hari dikirim lewat kotak surat. Item dipotong di perangkat penjual
  saat memasang dagangan (anti-curang penuh butuh inventaris di server).
- **Pemberitahuan**: `GET /v1/notices?since=` dipakai plugin Android saat game
  ditutup (jumlah surat baru dan dagangan laku).

### Save di server, pindah perangkat, konfigurasi, crash

- `POST/GET /v1/save`: cadangan save (maks. 600 KB). Inventaris dari save ini dipakai
  Pasar Pemain; kenaikan emas melebihi ±120/jam + 3.000 (di luar pembelian terverifikasi)
  dicatat di `/admin/api/flags`.
- `POST /v1/account/transfer` → kode 8 huruf (24 jam). `POST /v1/account/claim`
  (tanpa token) memindahkan akun ke perangkat baru; token lama tidak berlaku lagi.
- `GET /v1/config` (tanpa token): `yield_bonus` (0–1), `gacha_discount` (0–0,5),
  `rateup`, `event`, `min_version`, `announcement {id, title, body}`. Ubah lewat
  `POST /admin/api/config`, misalnya:

```
curl -X POST https://server/admin/api/config -H "X-Admin-Token: $ADMIN_TOKEN" \
  -d '{"yield_bonus":0.5,"announcement":{"id":"libur1","title":"Akhir Pekan Ganda","body":"Hasil urusan +50%!"}}'
```

- `POST /v1/crash` (opt-in): laporan crash, maks. 20 per pemasangan per hari →
  `/admin/api/crashes`.

### Umpan balik, jadwal acara, uji A/B, raid, status

- `POST /v1/feedback`: teks + tangkapan layar (JPEG/PNG ≤400 KB), 5 per hari. Dasbor →
  Umpan Balik untuk melihat gambar dan membalas (balasan + hadiah opsional lewat surat).
- Jadwal acara: dasbor → Jadwal & Konfigurasi, atau `POST /admin/api/schedule`
  `{title, start, end, overrides}`. Pengaturan aktif ditumpuk di atas `/v1/config`.
- Uji A/B: konfigurasi `experiments` = `[{"id":"diskon","variants":[{"name":"a","overrides":{}},
  {"name":"b","overrides":{"gacha_discount":0.2}}]}]`. Hasil (pemasangan, menit, H1/H7 per
  varian) di dasbor Statistik bila pemain mengizinkan statistik anonim.
- Raid aliansi: `GET /v1/raid`, `POST /v1/raid/attack` (2x sehari), `POST /v1/raid/claim`
  (raid sebelumnya). HP benteng = 3x total kekuatan anggota aktif.
- `GET /status`, cadangan harian (`BACKUP_DIR`), peringatan `ALERT_WEBHOOK`: lihat
  `docs/deploy.md`.

### Endpoint

| Metode | Jalur | Keterangan |
|---|---|---|
| POST | `/v1/auth/device` | Tukar ID perangkat dengan token |
| POST | `/v1/profile` | Kirim profil (termasuk ringkasan `city`) |
| GET | `/v1/leaderboard?cat=` | Papan peringkat |
| GET/POST | `/v1/chat`, `/v1/chat/report` | Chat aliansi dan laporan |
| GET/POST | `/v1/arena/opponents`, `/v1/arena/fight` | Arena |
| GET | `/v1/friends` | Kode sendiri, daftar teman, kotak masuk hadiah |
| POST | `/v1/friends/add`, `/v1/friends/remove` | Tambah (dengan `code`) / hapus teman |
| POST | `/v1/gift`, `/v1/gifts/claim` | Kirim hadiah / ambil hadiah masuk |
| GET | `/v1/player?id=` | Kunjungi kota pemain |
| GET/POST | `/v1/king`, `/v1/king/decree` | Raja Hari Ini dan titahnya |
| GET/POST | `/v1/guildwar`, `/v1/guildwar/attack` | Perang Wilayah Aliansi |
| GET/POST | `/v1/worldboss`, `/v1/worldboss/attack` | Bos Dunia |
| POST | `/v1/redeem` | Tukar kode hadiah |
| GET/POST | `/v1/mail`, `/v1/mail/claim` | Kotak surat dari pengelola, ambil hadiah sekali |
| POST | `/v1/stats` | Statistik anonim harian (tanpa token, opt-in di game) |
| GET/POST | `/v1/referral` | Kode undangan sendiri / masukkan kode pengundang |
| GET/POST | `/v1/season`, `/v1/season/claim` | Musim aliansi dan hadiahnya |
| GET/POST | `/v1/market`, `/v1/market/sell`, `/v1/market/buy`, `/v1/market/cancel` | Pasar pemain |
| GET | `/v1/notices?since=` | Ringkasan untuk notifikasi saat game ditutup |
| POST | `/v1/iap/verify` | Verifikasi pembelian Google Play |
| GET | `/admin`, `/admin/api/*` | Dasbor admin (header `X-Admin-Token`) |
| GET/POST | `/v1/tourney`, `/v1/tourney/join` | Turnamen silat online (daftar Senin–Sabtu, hasil Minggu) |

## Menjalankan

```bash
node server/server.js                         # port 8080, data di server/data/tlg.db
PORT=9000 DB_PATH=/data/tlg.db node server/server.js
node --test server/server.test.js             # tes server
GODOT=/path/ke/godot server/e2e.sh            # uji ujung ke ujung dengan klien Godot
```

Di game: **Pengaturan → Server Online**, isi alamat server (mis.
`https://tlg.contoh.id`), lalu **Sambungkan**. Kosongkan untuk kembali offline.

## Hosting

Butuh satu server kecil dengan HTTPS (Android memblokir HTTP biasa kecuali untuk
pengujian). Contoh pilihan:

- **VPS** (mis. 1 vCPU/1 GB): jalankan Docker di belakang Caddy atau Nginx untuk HTTPS
  otomatis:
  ```bash
  docker build -t tlg-server server/
  docker run -d --restart=always -p 127.0.0.1:8080:8080 -v tlg-data:/data tlg-server
  # Caddyfile:  tlg.contoh.id { reverse_proxy 127.0.0.1:8080 }
  ```
- **Fly.io / Railway / Render**: deploy `server/Dockerfile` dengan volume tetap di `/data`.

Data hanya satu file SQLite (`DB_PATH`); cadangkan file itu secara berkala.

## Batasan versi ini

- Profil dilaporkan klien, jadi kekuatan dan tahap bisa dipalsukan oleh pemain yang
  mengubah aplikasi. Hasil arena sudah dihitung server, tetapi memakai kekuatan yang
  dilaporkan. Untuk rilis kompetitif, logika ekonomi perlu pindah ke server
  (lihat `docs/server_design.md`).
- Aliansi masih tiga aliansi tetap (Garuda, Teratai, Macan); perang dan bos aliansi
  di game tetap simulasi di perangkat. Perang Wilayah memakai kekuatan yang
  dilaporkan klien, dan hadiahnya diambil di perangkat.
- Moderasi chat masih dasar (filter kata, lapor, blokir). Belum ada panel admin;
  tinjau tabel `reports` langsung di SQLite, mis.
  `sqlite3 tlg.db "SELECT c.name, c.text, COUNT(*) FROM reports r JOIN chat c ON c.id = r.message GROUP BY r.message"`.
