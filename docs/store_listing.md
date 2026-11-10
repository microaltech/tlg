# Listing Google Play

Teks siap tempel untuk **Main store listing**. Batas Play Console: judul 30 karakter,
deskripsi singkat 80 karakter, deskripsi lengkap 4.000 karakter. Grafis dibuat dengan
`tools/store_assets.gd` (lihat `docs/release_checklist.md`).

## Nama aplikasi

Nama aplikasi: **Tuan Nusantara** (dipakai di `project.godot`, kedua preset ekspor,
laporan masalah, dan cadangan Google Play Games). Sebelum rilis, cek di Play Store
dan PDKI (pdki-indonesia.dgip.go.id) bahwa nama ini belum dipakai pihak lain.

ID paket masih `com.microaltech.toplordlike`. ID paket tidak tampil sebagai nama
aplikasi, tetapi terlihat di alamat halaman Play Store dan **tidak bisa diganti
setelah rilis pertama**. Bila ingin menggantinya (mis. `com.microaltech.tuannusantara`),
lakukan sebelum unggah pertama. Di HP penguji, aplikasi dengan ID baru terpasang
sebagai aplikasi terpisah, jadi pindahkan progres dulu lewat Pengaturan → kode cadangan.

## Bahasa Indonesia (utama)

**Judul:** Tuan Nusantara

**Deskripsi singkat (≤80):**
Bangun kerajaanmu, rekrut penasihat legendaris, dan taklukkan Nusantara!

**Deskripsi lengkap:**

Dari kepala desa menjadi Maharaja! Bangun kota, rekrut penasihat legendaris, dan
satukan kerajaan-kerajaan Nusantara dalam game strategi kerajaan bernuansa
Indonesia.

⚔️ PERANG KOLOSAL
Pimpin pasukan tombak, berkuda, dan panah dalam pertempuran yang bisa Anda saksikan
langsung. Pilih susunan pasukan yang tepat untuk mengalahkan tiap musuh, taklukkan
wilayah di Peta Nusantara, dan kalahkan Buto penjaga candi kuno.

👑 BANGUN KERAJAAN
Tarik pajak, kelola sawah, rekrut prajurit, dan bangun keraton, pasar, lumbung,
serta barak. Tetapkan kebijakan kota, tangani bencana, gelar upacara Sekaten, dan
naik jabatan dari Camat sampai Maharaja.

🧑‍🤝‍🧑 PENASIHAT & ISTANA
Rekrut puluhan penasihat bertema sejarah dan legenda Nusantara, latih, beri pusaka
tempaan Besalen, dan naikkan gelar mereka hingga Mahapatih. Didik putra-putri
istana dan nikahkan mereka dengan wangsa bangsawan.

🎭 BUDAYA NUSANTARA
Tonton wayang cerita rakyat (Malin Kundang, Sangkuriang, Roro Jonggrang, Timun Mas),
jawab Kuis Sejarah Nusantara setiap hari, berburu di hutan, dan ikuti pacuan kuda.
Rayakan festival Tahun Baru, Ramadan & Lebaran, Kemerdekaan, Sumpah Pemuda, dan
Hari Pahlawan.

🌏 BERSAMA PEMAIN LAIN
Bergabung dengan aliansi, adu kekuatan di Arena, ikut Turnamen Silat, lawan Bos
Dunia bersama seluruh pemain, dan jadilah Raja Hari Ini.

Game ini bisa dimainkan offline. Berisi pembelian dalam aplikasi opsional dan
rekrut acak (peluang tiap kelangkaan ditampilkan di dalam game).

## English

**Title:** Tuan Nusantara

**Short description (≤80):**
Build your kingdom, recruit legendary advisors, and unite the archipelago!

**Full description:**

From village head to Maharaja! Build your city, recruit legendary advisors, and
unite the kingdoms of the Indonesian archipelago in a kingdom strategy game steeped
in Nusantara history and folklore.

⚔️ EPIC BATTLES
Lead spearmen, cavalry, and archers in battles you watch unfold. Choose the right
formation for each enemy, conquer regions on the Nusantara Map, and defeat the Buto
guardian of an ancient temple.

👑 BUILD YOUR KINGDOM
Collect taxes, tend rice fields, recruit soldiers, and build your palace, market,
granary, and barracks. Set city policies, handle disasters, hold royal ceremonies,
and rise through the ranks to Maharaja.

🧑‍🤝‍🧑 ADVISORS & PALACE
Recruit dozens of advisors inspired by Nusantara history and legend, train them,
equip heirlooms forged at the Smithy, and earn them titles up to Mahapatih. Raise
the palace children and arrange royal marriages with noble houses.

🎭 NUSANTARA CULTURE
Watch wayang folk tales, answer a daily Nusantara History Quiz, hunt in the
forest, and race horses. Celebrate New Year, Ramadan & Eid, Independence Day, Youth
Pledge Day, and Heroes' Day festivals.

🌏 PLAY WITH OTHERS
Join an alliance, battle in the Arena, enter the Silat Tournament, fight the World
Boss with every player on the server, and become King of the Day.

Playable offline. Contains optional in-app purchases and random recruitment (the
odds for each rarity are shown in the game).

## Kategori & konten

- **Kategori:** Game → Strategi. **Tag:** Strategi, Simulasi, Kerajaan.
- **Rating konten (IARC):** kekerasan kartun ringan (pertempuran tanpa darah);
  jawab **Ya** untuk "pembelian dalam aplikasi" dan **Ya** untuk item acak yang
  bisa dibeli (rekrut/gacha). Peluang sudah ditampilkan di halaman Rekrut, sesuai
  kebijakan Google Play tentang loot box.
- **Iklan:** pilih "Ya" bila build menyertakan AdMob.
- **Target audiens:** 13 tahun ke atas (ada pembelian dan item acak berbayar).
- **Chat (mode online):** bila server diaktifkan, nyatakan ada interaksi pengguna
  (chat aliansi) dengan fitur lapor dan blokir.
