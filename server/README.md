# Server sosial Top Lord Like

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
