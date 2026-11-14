# Menjalankan Server Tuan Nusantara

Server cukup satu VPS kecil (1 vCPU, 1 GB RAM, Ubuntu 22.04/24.04) dan satu domain.

## 1. Pasang & jalankan

```bash
# di VPS
curl -fsSL https://get.docker.com | sh
git clone <repo> tlg && cd tlg
cp server/.env.example server/.env   # isi DOMAIN dan ADMIN_TOKEN (openssl rand -hex 24)
docker compose -f server/docker-compose.yml up -d --build
```

Caddy otomatis membuat sertifikat HTTPS untuk `DOMAIN`. Isi alamat
`https://DOMAIN` di game (Pengaturan → Server Online) atau di build rilis.

## 2. Dasbor & pemantauan

- Dasbor admin: `https://DOMAIN/admin` (token = `ADMIN_TOKEN`).
- Status: `https://DOMAIN/status` → `ok`, jumlah pemain, permintaan & galat 1 jam terakhir,
  cadangan terakhir. Daftarkan alamat ini di layanan pemantau gratis (mis. UptimeRobot)
  dengan kata kunci `"ok":true` agar Anda diberi tahu bila server mati.
- `ALERT_WEBHOOK`: server mengirim pesan bila ada ≥20 galat dalam 10 menit (maks. sekali
  per jam). Bisa diarahkan ke webhook Slack/Discord.
- Log: `docker compose -f server/docker-compose.yml logs -f server`.

## 3. Cadangan

- Server membuat salinan database harian di volume `/data/backups`
  (`tlg-YYYY-MM-DD.db`, 7 hari terakhir disimpan). Buat cadangan sekarang:
  dasbor → API `POST /admin/api/backup`.
- Simpan juga salinan di luar VPS, mis. cron harian:

```bash
docker compose -f server/docker-compose.yml cp server:/data/backups ./backups-$(date +%F)
```

- Memulihkan: hentikan server, salin file cadangan menjadi `/data/tlg.db`, jalankan lagi.

## 4. Pembaruan

```bash
git pull && docker compose -f server/docker-compose.yml up -d --build
```

Database di-upgrade otomatis saat server mulai (tabel/kolom baru dibuat bila belum ada).
