# Penyeimbangan Ekonomi

Angka-angka ekonomi diuji dengan bot simulasi `tools/sim_economy.gd` yang
memainkan `GameModel` sebagai pemain gratis (tanpa pembelian) selama N hari.
Setiap sesi, bot mengerjakan semua urusan kota, mengunjungi selir, mendidik anak,
menyerang kampanye selama prajurit cukup, melatih penasihat termurah, ikut
aliansi/bos/perang/arena, mengklaim semua hadiah, dan memakai emas untuk rekrut x10.

```bash
godot --headless --path . --script res://tools/sim_economy.gd -- 30 4 1
#                                                       hari ─┘  │ └─ seed
#                                                   sesi/hari ───┘ (2, 3, 4, 6)
```

Keluaran: tabel progres harian, tonggak (tahap pada hari ke-1/3/7/14/21/30 dan
hari naik jabatan), sumber emas, serta jumlah anak, pernikahan, dan pejabat.

## Temuan awal (sebelum penyeimbangan, 4 sesi/hari)

| Ukuran | Hasil | Masalah |
|---|---|---|
| Tahap di hari ke-1 | 29 | Kampanye awal terlalu murah |
| Jabatan | Gubernur di hari ke-1, Perdana Menteri di hari ke-6 | Seluruh jalur jabatan habis dalam seminggu |
| Anak lahir (30 hari) | 700 | Anak bisa dididik sampai dewasa seketika, lalu dinikahkan untuk prestise dan atribut permanen |
| Pangan di hari ke-30 | 268 juta | Hampir tidak ada yang memakai pangan |
| Perak di hari ke-30 | 214 juta | Semua penasihat mentok di batas level, perak tidak terpakai |
| Emas | ~720/hari | Semua 13 penasihat terkumpul di hari ke-11 |

## Perubahan

| Konstanta (`game_data.gd`) | Lama | Baru | Alasan |
|---|---|---|---|
| `SOLDIER_GRAIN` (pangan per prajurit baru) | 0 | 0,75 | Pangan jadi sumber daya yang diperebutkan, seperti di Top Lord |
| `CHILD_TRAIN_SECONDS` (jeda didik per anak) | 0 | 1.800 | Anak butuh ±2,5 hari bermain untuk dewasa, bukan seketika |
| `CHILD_TRAIN_GRAIN` | 60/level | 200/level | Mendidik anak benar-benar memakai pangan |
| `STAGE_SOLDIERS_BASE` | 300 | 600 | Kampanye awal tidak gratis |
| `LOSS_RATIO_MIN` | 0,25 | 0,5 | Penasihat super kuat tetap kehilangan prajurit |
| Prajurit awal | 1.000 | 2.500 | Pemain baru tetap bisa langsung menang 3 tahap |
| `UPGRADE_COST_EXP` | 1,6 | 2,0 | Perak tetap menjadi kendala, bukan cuma batas level |
| Prestise jabatan | 150 / 600 / 1.800 / 5.000 / 12.000 | 300 / 1.500 / 6.000 / 12.000 / 25.000 | Jabatan menjadi tujuan jangka menengah–panjang |
| Emas peti aktivitas | 30 / 50 / 100 | 20 / 30 / 60 | Mengurangi emas harian |
| Emas misi harian | 20–40 | 10–25 (×0,6) | Mengurangi emas harian |
| Batas beli emas di toko aliansi & arena | 2/hari | 1/hari | Mengurangi emas harian |

## Hasil sesudah penyeimbangan (seed 1)

| Sesi/hari | Tahap h1 / h7 / h30 | Camat | Bupati | Gubernur | Menteri | Perdana Menteri |
|---|---|---|---|---|---|---|
| 2 | 8 / 42 / 61 | h2 | h3 | h8 | h25 | > 30 hari |
| 4 | 16 / 47 / 66 | h1 | h2 | h6 | h22 | > 30 hari |
| 6 | 24 / 52 / 69 | h1 | h1 | h4 | h19 | > 30 hari |

Dengan 4 sesi/hari selama 30 hari:
- 47 anak lahir (bukan 700), 34 menikah, dan 8 menjadi pejabat.
- Cerita mencapai bab 6.
- Pangan langka di pertengahan permainan dan baru menumpuk setelah kampanye melambat.
- Perak tetap berada di kisaran puluhan sampai ratusan ribu, sehingga tetap berguna.
- Emas sekitar 660/hari termasuk hadiah cerita sekali-jalan, atau sekitar 550/hari untuk pemasukan rutin. Ini setara satu rekrut x10 tiap ±2 hari.

## Catatan untuk iterasi berikutnya

- Emas masih cukup murah hati untuk pemain gratis: 13 penasihat terkumpul dalam
  ±1 minggu, dan bintang hampir penuh di hari ke-30. Bila ingin koleksi lebih
  lama, tambah penasihat baru atau kurangi emas event dan arena.
- Kampanye bersifat eksponensial (1,16× per tahap), sehingga melambat di sekitar
  tahap 60–70. Konten akhir (tahap > 70, Perdana Menteri) ditujukan untuk
  pemain yang bermain lebih dari satu bulan.
- Jalankan ulang bot setiap kali mengubah angka di `game_data.gd`.

## Penyeimbangan ulang setelah fitur tambahan

Fitur tambahan berikutnya menambah sumber emas dan kekuatan: 6 penasihat baru
(19 total), pusaka, Menara Ujian, Tiket Musim (jalur gratis), pencapaian, dan
iklan berhadiah. Bot kini ikut memakai menara, Tiket Musim, pencapaian, dan
iklan. Tambahkan argumen `noads` untuk mensimulasikan pemain yang tidak menonton
iklan.

| Ukuran (4 sesi/hari, 30 hari) | Sebelum fitur tambahan | Sesudah, ambang lama | Sesudah, ambang baru |
|---|---|---|---|
| Tahap di hari ke-30 | 66 | 72 | 71 |
| Menteri tercapai | hari ke-22 | hari ke-13 | hari ke-21 |
| Emas didapat | 19,9 ribu | 26,5 ribu | 26,5 ribu (24,6 ribu tanpa iklan) |

Percepatan terutama datang dari bertambahnya penasihat, bukan dari pusaka (bot
tidak memasang pusaka). Karena itu yang disesuaikan adalah ambang prestise
jabatan atas, bukan fitur barunya:

| Jabatan | Lama | Baru |
|---|---|---|
| Menteri | 12.000 | 16.000 |
| Perdana Menteri | 25.000 | 35.000 |

Sumber emas tambahan sekitar +30%: menara, Tiket Musim, dan pencapaian sekitar
4,1 ribu dalam 30 hari (sebagian sekali-jalan), ditambah iklan 1,8 ribu. Semua
19 penasihat terkumpul dalam 30 hari. Bila koleksi dirasa terlalu cepat,
turunkan `ACHIEVEMENT_GOLD` atau emas di `AD_REWARDS`.

## Penyeimbangan setelah bangunan, ekspedisi, dan kuda

Bangunan kota (bonus hasil urusan), ekspedisi (sumber daya, item, dan pusaka),
dan kuda tunggangan (bonus atribut 4–12%) mempercepat kampanye. Bot kini juga
membangun, mengirim ekspedisi, membeli kuda perak, memberi pakan, dan
menunggangkan kuda ke penasihat terkuat. Formasi tetap Seimbang.

| Ukuran (4 sesi/hari, 30 hari, seed 1–3) | Sebelum | Fitur baru, ambang lama | Ambang baru |
|---|---|---|---|
| Tahap di hari ke-30 | 71–73 | 75–76 | 75–76 |
| Menteri tercapai | hari ke-21 | hari ke-15 sampai 18 | hari ke-18 sampai 22 |
| Bangunan di hari ke-30 | – | semua level 8 | semua level 8 |

Hasil ekspedisi sempat dua kali lebih besar dan memajukan Menteri ke hari ke-15;
pengali `yields` di `EXPEDITIONS` sudah dipangkas setengahnya. Ambang jabatan:

| Jabatan | Lama | Baru |
|---|---|---|
| Menteri | 16.000 | 17.500 |
| Perdana Menteri | 35.000 | 40.000 |

Ambang 19.000 juga dicoba, tetapi Menteri mundur ke hari ke-22 sampai 30 karena
pengali jabatan ikut tertahan, jadi dipilih 17.500.
