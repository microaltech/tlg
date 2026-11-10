# Checklist Uji di Banyak HP

Pakai APK debug (`tools/build_android.sh debug`) agar **Pengaturan → Uji Cepat**
tersedia. Bagian itu tidak pernah ada di build rilis (`OS.is_debug_build()`).

## Alat uji cepat (build debug)

| Tombol | Fungsi |
|---|---|
| +10 Tahap | Lompat 10 tahap kampanye untuk membuka fitur (pasar, kebun, candi, dll.) |
| +Sumber Daya | +1 juta perak/pangan/prajurit, +5000 emas & prestise, 10 item penting |
| Maju 1 Jam / 1 Hari | Majukan jam game (pengisian ulang, hari baru, acara, panen) |

Jam game yang dimajukan disimpan di `user://debug.cfg`. Untuk kembali normal,
hapus data aplikasi (Setelan Android → Aplikasi → Tuan Nusantara → Hapus data).

## HP yang disarankan

Minimal satu dari tiap kelompok:

- [ ] Android 8–9, RAM 2–3 GB, GPU Mali (mis. Samsung A10/A20, Oppo A-series)
- [ ] Android 11–12, GPU Adreno kelas menengah (mis. Redmi Note, Poco)
- [ ] Android 13–14, layar tinggi 20:9 (mis. Samsung A54, Pixel)
- [ ] Tablet atau HP layar lebar (rasio 4:3 sampai 16:10)
- [ ] Satu HP dengan bahasa sistem Inggris

## 10 menit pertama (HP baru, tanpa uji cepat)

- [ ] Game terbuka < 5 detik, tanpa layar hitam lama
- [ ] Tutorial 14 langkah lancar: pajak → prajurit → surat sambutan → penasihat →
      latih → kampanye → serang → rekrut → istana → kunjungi → misi
- [ ] Tombol "Lewati tutorial" bekerja dan tidak bisa membuat tutorial macet
- [ ] Hadiah tutorial (100 emas, 2000 perak) dan surat sambutan diterima
- [ ] Kalender login muncul setelah tutorial; gambar tampil, bisa diklaim
- [ ] Tahap 1–5 bisa dimenangkan tanpa membeli apa pun

## Tampilan

- [ ] Tidak ada teks terpotong atau tombol keluar layar (Indonesia & Inggris)
- [ ] Layar tinggi: konten memanjang, tanpa pita hitam
- [ ] Tablet: konten melebar, tanpa pita hitam; panel tetap terbaca
- [ ] Mode gelap dan ukuran tampilan 90%/110% (Pengaturan)
- [ ] Gulir dengan jari halus di semua halaman dan panel

## Fitur (pakai uji cepat bila perlu)

- [ ] Urusan Kerajaan: tiap tab, tiap ubin bisa dibuka dan ditutup
- [ ] Acara Sejarah: kemajuan tugas bertambah, klaim tugas & hadiah akhir,
      kostum muncul di Lemari Busana
- [ ] Lemari Busana: beli, pakai, lepas; potret berubah di halaman Penasihat,
      tayangan perang, dan perburuan
- [ ] Kotak Surat: surat sambutan; dengan server, surat dari `admin.js send-mail`
- [ ] Musik berganti: kota, istana/rekrut, kampanye, perburuan/pacuan/candi
      (petualangan), wayang, armada/pasar (laut); kembali ke musik halaman saat
      panel ditutup
- [ ] Tayangan perang, duel, perburuan, pacuan: tombol Lewati dan Lanjut
- [ ] Maju 1 Hari: misi harian reset, kalender login lanjut, kebun bisa dipanen

## Ketahanan

- [ ] Tutup paksa saat tayangan perang lalu buka lagi: progres tersimpan
- [ ] Mode pesawat: game tetap jalan, fitur online menampilkan pesan yang jelas
- [ ] Hemat baterai: 30 FPS, tidak panas setelah 15 menit
- [ ] Notifikasi muncul saat urusan penuh (game ditutup ≥ 1 jam)
- [ ] Putar layar terkunci potret
- [ ] Bila crash: Pengaturan → Salin Laporan, kirim ke pengembang

## Mode online (bila server dipakai)

- [ ] Sambung server, chat, teman, Bos Dunia, Turnamen
- [ ] Statistik anonim mati sejak awal; setelah dinyalakan, `node server/admin.js stats`
      menampilkan pemasangan ini keesokan harinya
