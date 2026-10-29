# Kebijakan Privasi — Top Lord Like

_Berlaku sejak: [isi tanggal rilis] · Pengembang: [nama pengembang] · Kontak: [email dukungan]_

> **Sebelum dipublikasikan:** isi kolom dalam tanda kurung siku, lalu hosting
> halaman ini di URL publik (mis. GitHub Pages atau situs Anda). Google Play
> mewajibkan URL kebijakan privasi di Play Console. Ringkasan yang sama tampil di
> dalam game: **Pengaturan → Kebijakan Privasi** (`PRIVACY_SECTIONS` di
> `scripts/core/game_data.gd`). Kalau Anda menambah server, iklan, atau analitik
> online, perbarui dokumen ini dan formulir Data Safety.

## Ringkasan

Top Lord Like adalah game offline. Game ini tidak punya akun, tidak punya server,
dan tidak mengirim data pribadi Anda ke pengembang atau pihak ketiga.

## Data yang disimpan di perangkat Anda

Semua data berikut disimpan di penyimpanan internal aplikasi dan hanya bisa
dibaca oleh game ini.

| Data | Isi | Tujuan |
|---|---|---|
| Progres game (`save.json`) | Sumber daya, penasihat, istana, aliansi simulasi, nama Tuan yang Anda pilih | Melanjutkan permainan |
| Pengaturan (`settings.cfg`) | Volume, hemat baterai, notifikasi, statistik | Menyimpan preferensi |
| Statistik bermain (`analytics.json`) | Jumlah sesi, lama bermain, hari aktif, hitungan aksi game | Menampilkan statistik Anda sendiri. Bisa dimatikan dan dihapus di Pengaturan |
| Laporan crash dan log (`crash_reports.json`, `logs/`) | Waktu crash, versi game, dan log teknis Godot | Membantu Anda melaporkan masalah |

Data di atas **tidak dikirim** ke mana pun. Tombol **Salin Laporan** hanya
menyalin teks laporan (versi game, sistem operasi, model perangkat, dan log
crash) ke clipboard. Anda sendiri yang memutuskan apakah akan mengirimkannya.

## Pemain lain, chat, dan peringkat

Secara bawaan, anggota aliansi, lawan arena, perang guild, chat, dan papan
peringkat adalah simulasi yang berjalan di perangkat Anda. Pesan yang Anda ketik
di chat aliansi disimpan di save lokal dan tidak dikirim ke siapa pun.

**Mode online (opsional).** Bila Anda mengisi alamat server di Pengaturan → Server
Online, game mengirim ke server itu: ID perangkat acak buatan game (bukan ID iklan
atau nomor perangkat), nama Tuan, kostum dan bingkai profil, aliansi, kekuatan,
tahap kampanye, rekor menara, prestise, pesan chat aliansi, serta hasil arena
online. Data ini dipakai untuk papan peringkat, chat, dan arena bersama pemain lain,
dan dapat dilihat pemain lain (nama, kostum, kekuatan, pesan chat). Server
dikelola oleh [NAMA PENGEMBANG]; data disimpan selama akun aktif dan dapat dihapus
atas permintaan ke [EMAIL KONTAK]. Mengosongkan alamat server menghentikan semua
pengiriman.

## Pembelian dalam aplikasi

Pembelian diproses oleh Google Play sesuai
[Kebijakan Privasi Google](https://policies.google.com/privacy). Game hanya
menerima konfirmasi pembelian (ID produk, token pembelian, dan status). Game
tidak pernah menerima data kartu, rekening, atau identitas pembayaran Anda.

## Iklan berhadiah

Iklan video hanya diputar bila Anda sendiri menekan tombol **Iklan** untuk
mendapat hadiah (tiket rekrut, emas, atau isi ulang urusan), paling banyak
beberapa kali per hari. Pada build yang menyertakan **Google AdMob**, SDK
AdMob dapat mengumpulkan ID iklan perangkat, alamat IP, dan data interaksi
iklan untuk menampilkan, mengukur, dan mencegah penipuan iklan, sesuai
[kebijakan Google](https://policies.google.com/technologies/ads). Anda dapat
mereset atau menghapus ID iklan di pengaturan Android (Google → Iklan).
Build tanpa AdMob tidak menampilkan iklan sama sekali.

## Notifikasi

Pengingat (urusan kota penuh, rekrut gratis, dan hadiah login) dijadwalkan secara
lokal oleh sistem Android. Notifikasi tidak memakai server push. Matikan kapan
saja di **Pengaturan → Notifikasi** atau di pengaturan Android.

## Izin aplikasi

- `INTERNET`: untuk iklan, pembelian, Google Play Games, dan mode online. Game tidak
  mengirim apa pun ke server sosial bila alamat server tidak diisi.

- `POST_NOTIFICATIONS` (Android 13+): untuk menampilkan pengingat. Hanya diminta
  bila build menyertakan plugin notifikasi.
- `com.android.vending.BILLING`: untuk pembelian lewat Google Play. Hanya ada
  bila build menyertakan plugin billing.

## Anak-anak

Game ini tidak secara sengaja mengumpulkan data dari siapa pun, termasuk anak di
bawah 13 tahun, karena tidak ada data yang dikirim keluar dari perangkat.

## Menghapus data

- **Pengaturan → Hapus Statistik** menghapus statistik bermain.
- **Pengaturan → Mulai Ulang** menghapus progres game.
- Menghapus aplikasi atau memakai "Hapus data" di pengaturan Android menghapus
  semua data game.

## Perubahan kebijakan

Perubahan akan diumumkan di halaman ini, dengan tanggal berlaku yang diperbarui.
