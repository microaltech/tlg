# Kebijakan Privasi — Tuan Nusantara

_Berlaku sejak: [isi tanggal rilis] · Pengembang: [nama pengembang] · Kontak: [email dukungan]_

> **Sebelum dipublikasikan:** isi kolom dalam tanda kurung siku, lalu hosting
> halaman ini di URL publik (mis. GitHub Pages atau situs Anda). Google Play
> mewajibkan URL kebijakan privasi di Play Console. Ringkasan yang sama tampil di
> dalam game: **Pengaturan → Kebijakan Privasi** (`PRIVACY_SECTIONS` di
> `scripts/core/game_data.gd`). Kalau Anda menambah server, iklan, atau analitik
> online, perbarui dokumen ini dan formulir Data Safety.

## Ringkasan

Tuan Nusantara adalah game offline. Game ini tidak punya akun, tidak punya server,
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

Data di atas **tidak dikirim** ke mana pun, kecuali Anda menyalakan **Bagikan
statistik anonim** (lihat di bawah). Tombol **Salin Laporan** hanya
menyalin teks laporan (versi game, sistem operasi, model perangkat, dan log
crash) ke clipboard. Anda sendiri yang memutuskan apakah akan mengirimkannya.

**Statistik anonim (opsional, mati sejak awal).** Bila Anda menyalakan
Pengaturan → Privasi → *Bagikan statistik anonim*, game mengirim satu laporan
ringkas sehari ke server pengembang: ID pemasangan acak (bukan ID akun, ID iklan,
atau nomor perangkat), versi game, bahasa, jumlah sesi, lama bermain, jumlah hari
aktif, tahap kampanye, jabatan, apakah tutorial selesai, dan jumlah tiap jenis aksi
game (mis. berburu, bertempur). Tidak ada nama, isi chat, lokasi, atau kontak.
Data ini hanya dipakai untuk memperbaiki keseimbangan dan alur game, tidak dijual
dan tidak dibagikan. **Hapus Statistik** membuat ID pemasangan baru sehingga
laporan lama tidak bisa dikaitkan lagi dengan Anda. Mematikan pilihan ini
menghentikan pengiriman. Bila pilihan ini nyala, laporan crash (versi game, model
perangkat, nama kartu grafis, jejak kejadian, dan potongan log teknis) juga dikirim
setelah game berhenti tiba-tiba.

## Pemain lain, chat, dan peringkat

Secara bawaan, anggota aliansi, lawan arena, perang guild, chat, dan papan
peringkat adalah simulasi yang berjalan di perangkat Anda. Pesan yang Anda ketik
di chat aliansi disimpan di save lokal dan tidak dikirim ke siapa pun.

**Mode online (opsional).** Bila Anda mengisi alamat server di Pengaturan → Server
Online, game mengirim ke server itu: ID perangkat acak buatan game (bukan ID iklan
atau nomor perangkat), nama Tuan, kostum dan bingkai profil, aliansi, kekuatan,
tahap kampanye, rekor menara, prestise, ringkasan kota (jabatan, level bangunan,
jumlah penasihat, wilayah, kapal, dan besan), pesan chat aliansi, daftar teman dan
hadiah yang dikirim, titah bila Anda menjadi Raja Hari Ini, serangan Perang
Wilayah dan Bos Dunia, kode hadiah yang Anda tukar, surat yang hadiahnya Anda ambil
dari Kotak Surat, kode undangan yang Anda masukkan, dagangan dan pembelian di Pasar
Pemain (nama Tuan tampil di dagangan), poin musim aliansi, token pembelian Google
Play untuk verifikasi, serta hasil arena online. Saat game ditutup, aplikasi
mencadangkan progres game ke server (dipakai juga untuk Pindah Perangkat dan
memeriksa kecurangan di Pasar Pemain). Aplikasi juga memeriksa server sekitar 4 jam sekali untuk memberi tahu surat baru atau dagangan
yang laku (mati bila notifikasi dimatikan atau mode online tidak dipakai).

**Bagikan.** Tombol Bagikan membuat gambar kartu di perangkat lalu membuka menu
bagikan Android. Gambar hanya terkirim ke aplikasi yang Anda pilih sendiri. Data ini dipakai untuk papan peringkat, chat,
arena, teman, kunjungan kota, Raja Hari Ini, dan Perang Wilayah bersama pemain lain,
dan dapat dilihat pemain lain (nama, kostum, kekuatan, ringkasan kota, pesan chat). Server
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
