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
