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
  tetap simulasi di perangkat.
- Moderasi chat masih dasar (filter kata, lapor, blokir). Belum ada panel admin;
  tinjau tabel `reports` langsung di SQLite, mis.
  `sqlite3 tlg.db "SELECT c.name, c.text, COUNT(*) FROM reports r JOIN chat c ON c.id = r.message GROUP BY r.message"`.
