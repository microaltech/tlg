# Jawaban Formulir Data Safety (Google Play Console)

Panduan pengisian **App content → Data safety** untuk build saat ini, yaitu game
offline tanpa server, iklan, atau SDK analitik pihak ketiga. Jika nanti Anda
menambahkan server (lihat `docs/server_design.md`), iklan, Firebase, atau
pelaporan crash online, jawaban di bawah **harus diubah**.

| Pertanyaan | Jawaban | Alasan |
|---|---|---|
| Apakah aplikasi mengumpulkan atau membagikan data pengguna yang wajib dilaporkan? | **Tidak** | Semua data hanya disimpan di perangkat. Menurut definisi Google, data yang tidak pernah meninggalkan perangkat tidak termasuk "dikumpulkan" |
| Apakah semua data pengguna dienkripsi saat transit? | Tidak berlaku | Tidak ada data yang dikirim |
| Apakah pengguna bisa meminta penghapusan data? | Ya (di dalam aplikasi) | Hapus Statistik, Mulai Ulang, atau hapus aplikasi |

Catatan:
- **Pembelian dalam aplikasi** diproses oleh Google Play Billing. Data transaksi
  yang ditangani Google tidak perlu dilaporkan oleh pengembang.
- **Tombol Salin Laporan** hanya mengisi clipboard. Laporan yang dikirim pemain
  lewat email dihitung sebagai komunikasi sukarela, bukan pengumpulan otomatis.
- **Notifikasi** dijadwalkan secara lokal (AlarmManager), bukan Firebase Cloud
  Messaging.

## Bila build menyertakan AdMob (iklan berhadiah)

Jawaban "Tidak mengumpulkan data" di atas **tidak berlaku lagi**. Ikuti panduan
resmi Google untuk SDK AdMob, yang biasanya mencakup:

| Jenis data | Dikumpulkan | Dibagikan | Tujuan |
|---|---|---|---|
| ID perangkat atau lainnya (ID iklan) | Ya | Ya (Google) | Iklan/pemasaran, analitik, pencegahan penipuan |
| Perkiraan lokasi (dari IP) | Ya | Ya (Google) | Iklan, pencegahan penipuan |
| Interaksi aplikasi (tayangan & ketukan iklan) | Ya | Ya (Google) | Iklan, analitik |
| Diagnostik (log crash SDK) | Ya | Ya (Google) | Analitik |

- Di bagian **Ads** pilih **"Ya, aplikasi berisi iklan"**.
- Tambahkan izin `com.google.android.gms.permission.AD_ID` (biasanya ikut dari
  plugin) dan isi deklarasi **Advertising ID** di Play Console.
- Untuk pengguna di EEA/Inggris, tampilkan formulir persetujuan (UMP SDK)
  sebelum memuat iklan.
- Ganti `REWARDED_UNIT_ID` di `scripts/core/ads.gd` dengan ID unit dari konsol
  AdMob. ID bawaan adalah ID uji resmi Google.

## Bila mode online (server sosial) diaktifkan di rilis

Isi formulir Data Safety dengan data berikut (dikumpulkan, dibagikan ke pemain lain
di dalam game, tidak dijual, terenkripsi saat dikirim lewat HTTPS, bisa dihapus atas
permintaan):

| Kategori Play Console | Data | Tujuan |
|---|---|---|
| Info pribadi → Nama | Nama Tuan (nama tampilan) | Fungsi aplikasi, papan peringkat |
| Pesan → Pesan dalam aplikasi lainnya | Chat aliansi | Fungsi aplikasi |
| Aktivitas aplikasi → Konten buatan pengguna lainnya | Profil game (kekuatan, tahap, aliansi) | Fungsi aplikasi |
| ID perangkat atau lainnya | ID perangkat acak buatan game | Akun tanpa login |

Chat dengan pemain sungguhan termasuk konten buatan pengguna (UGC). Game sudah
menyediakan tombol Laporkan dan Blokir di tiap pesan pemain lain; pastikan laporan
ditinjau secara berkala (lihat `server/README.md`).

## Bila statistik anonim dipakai (opt-in)

Build ini punya pilihan **Bagikan statistik anonim** (mati sejak awal). Bila build
rilis mengisi `application/config/stats_url` atau alamat server, data berikut bisa
terkirim setelah pemain menyalakannya, jadi jawab **Ya, mengumpulkan data**:

| Kategori Play Console | Data | Dibagikan | Wajib/Opsional | Tujuan |
|---|---|---|---|---|
| Info aplikasi & performa → Log crash, Diagnostik | Laporan crash (versi, model perangkat, GPU, log) | Tidak | Opsional | Analitik |
| Aktivitas aplikasi → Interaksi aplikasi | Jumlah sesi, lama bermain, hari aktif, hitungan aksi, tahap, jabatan, tutorial selesai | Tidak | Opsional | Analitik |
| ID perangkat atau lainnya | ID pemasangan acak (bisa direset dengan Hapus Statistik) | Tidak | Opsional | Analitik |

Data diproses secara efemeral? **Tidak** (disimpan per hari di server). Enkripsi
saat transit: Ya, bila server memakai HTTPS (wajib).

## Isian lain di App content

| Bagian | Isian yang disarankan |
|---|---|
| Privacy policy | URL publik dari `docs/privacy_policy.md` |
| Ads | Tidak berisi iklan |
| App access | Semua fitur tersedia tanpa login |
| Target audience | 13+ (ada mekanik gacha / pembelian acak) |
| Content rating (IARC) | Kekerasan ringan bergaya kartun (pertempuran tanpa darah); pembelian dalam aplikasi; elemen acak berbayar (gacha). Isi kuesioner dengan jujur |
| Government apps / Financial features / Health | Tidak |
| Data penghapusan akun | Tidak berlaku (tanpa akun) |

## Gacha dan pembelian acak

Kebijakan Google Play mewajibkan peluang item acak berbayar ditampilkan sebelum
pembelian. Game ini sudah menampilkan peluang Legenda 4%, Epik 21%, dan Langka
75%, serta jaminan Legenda di tarikan ke-50, pada halaman Rekrut dan Panduan.

## Bila build memakai server sosial (mode online)

Server hanya dipakai bila pemain mengisi alamat server di Pengaturan, atau bila
build rilis Anda mengisinya lebih dulu. Bila alamat diisi lebih dulu, jawab formulir
dengan **Ya, mengumpulkan data**:

| Jenis data | Dikumpulkan | Dibagikan | Wajib/Opsional | Tujuan |
|---|---|---|---|---|
| ID pengguna (ID akun acak dari ID perangkat buatan game) | Ya | Tidak | Wajib untuk mode online | Fungsi aplikasi, manajemen akun |
| Nama pengguna (nama Tuan) | Ya | Tidak | Wajib untuk mode online | Fungsi aplikasi (peringkat, chat, teman) |
| Pesan dalam aplikasi (chat aliansi) | Ya | Tidak | Opsional | Fungsi aplikasi |
| Aktivitas aplikasi lainnya (kekuatan, tahap, ringkasan kota, lencana, serangan Perang Wilayah/Bos Dunia, pendaftaran turnamen, teman, hadiah, kode yang ditukar, kode undangan, dagangan Pasar Pemain) | Ya | Tidak | Wajib untuk mode online | Fungsi aplikasi |
| Info keuangan → Riwayat pembelian (token pembelian untuk verifikasi) | Ya | Tidak | Wajib bila membeli | Fungsi aplikasi, pencegahan penipuan |

- **Enkripsi saat transit:** Ya, asalkan server di-hosting dengan HTTPS (wajib).
- **Penghapusan data:** sediakan alamat email permintaan hapus akun (lihat
  `docs/privacy_policy.md`) dan hapus baris pemain di database server.
- Laporan chat (`reports`) dipakai untuk moderasi; sebutkan di kebijakan privasi.
