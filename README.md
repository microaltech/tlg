# Top Lord Like — Game Android Idle Strategi Kerajaan (Godot 4)

Prototipe game bergaya *Top Lord*: Anda seorang Tuan yang mengurus kota,
melatih penasihat, menaklukkan tahap kampanye, mengurus istana (selir & anak),
dan naik jabatan dari **Kepala Desa** hingga **Perdana Menteri**.

## Pilih engine yang mana? → **Godot 4**

| Kriteria | Java Native (Android SDK) | **Godot 4** | Unity |
|---|---|---|---|
| Cocok untuk game UI/menu 2D seperti Top Lord | Bisa, tapi semua dibuat manual | **Sangat cocok** (sistem Control/UI bawaan kuat) | Cocok |
| Multi-platform (Android, iOS, PC, Web) | Hanya Android | **Ya** | Ya |
| Biaya / lisensi | Gratis | **Gratis, MIT, tanpa royalti** | Gratis sampai batas pendapatan, lalu berbayar |
| Ukuran APK kosong | Paling kecil | **~25–35 MB** | ~40–60 MB |
| Kurva belajar | Tinggi untuk game | **Rendah (GDScript mirip Python)** | Sedang (C#) |
| Ekosistem iklan/IAP/analitik | Paling lengkap (SDK resmi) | Cukup (plugin AdMob, Google Play Billing) | **Paling matang** |
| Kecepatan iterasi | Lambat (build Gradle) | **Sangat cepat** (editor ringan, run instan) | Sedang (editor berat) |

**Kesimpulan:**

- **Godot 4 (direkomendasikan)** — Top Lord pada dasarnya adalah game *idle/SLG*
  yang didominasi menu, angka, dan progresi, bukan grafis 3D berat. Godot unggul
  di UI 2D, ringan, gratis tanpa royalti, dan sekali coding bisa ekspor ke
  Android, iOS, PC, dan Web.
- **Unity** — pilih bila tim sudah terbiasa C#/Unity atau sangat bergantung pada
  banyak SDK monetisasi pihak ketiga (ad mediation, attribution, dll.).
- **Java Native** — tidak disarankan: hanya Android, dan Anda harus membangun
  sendiri sistem scene, animasi, UI game, dan resource manager.

Untuk fitur online (PvP antar-server, aliansi, chat, leaderboard) Anda butuh
**backend** terpisah apa pun engine-nya, misalnya Nakama (ada SDK Godot resmi),
Firebase, atau server sendiri (Go/Node.js + PostgreSQL). Simpan semua logika
penting (hadiah, pembelian) di server agar tidak bisa dicurangi.

## Fitur prototipe

- **Kota** — Tarik Pajak (perak, dari Kecerdasan), Kelola Sawah (pangan, dari
  Politik), Rekrut Prajurit (dari Karisma; tiap prajurit baru makan 0,75 pangan). Tiap urusan memakai *charge* yang
  terisi 1 per 60 detik, tetap terisi saat game ditutup (offline progress).
- **Pengaturan** — tombol Pengaturan di menu Kota: nama Tuan (tampil di header,
  aliansi, arena, peringkat), slider volume musik & efek suara, mode hemat
  baterai (30 FPS + gambar ulang hanya saat ada perubahan), nyala/mati
  notifikasi, simpan manual, dan mulai ulang. Preferensi perangkat disimpan di
  `user://settings.cfg`, terpisah dari progres game.
- **Kerjakan Semua** — sejak Camat, satu tombol menghabiskan urusan kota, energi
  kunjungan, dan mendidik anak yang siap.
- **Banner rate-up** — tiap minggu satu Legenda unggulan; 50% Legenda adalah
  unggulan, dan bila meleset Legenda berikutnya pasti unggulan.
- **Pusaka** — senjata, kitab, dan perhiasan (3 kelangkaan) dari tahap besar,
  perang, dan menara; pasang ke penasihat, tingkatkan sampai +9, atau lebur.
- **Menara Ujian** — lantai bertingkat (dari Tahap 15) dengan kekuatan tempur,
  5 percobaan per hari, reset mingguan, hadiah pusaka tiap lantai ke-5, dan
  papan peringkat "Menara".
- **Tiket Musim** — battle pass 30 hari, 30 tingkat, jalur gratis dan premium
  (IAP `season_pass`).
- **Paket terbatas waktu** — muncul setelah naik jabatan atau 3 kekalahan
  beruntun (IAP `offer_promote`, `offer_rescue`).
- **Pencapaian** — 12 pencapaian bertingkat dengan hadiah emas; dilaporkan ke
  Google Play Games bila plugin terpasang.
- **Iklan berhadiah** — tiket rekrut, isi penuh urusan, dan emas dengan batas
  harian (autoload `Ads`, AdMob; mode uji di build debug).
- **Cerita lanjutan & gelar kehormatan** — bab 7–8 setelah Perdana Menteri,
  gelar Patih (+5%) dan Mahapatih (+10% semua hasil urusan).
- **Cadangan save** — kode cadangan yang bisa disalin/ditempel di Pengaturan,
  dan simpan/muat lewat Google Play Games.
- **Dua bahasa** — Indonesia dan English, pilih di Pengaturan (default mengikuti
  bahasa perangkat). Lihat bagian "Bahasa".
- **Selamat datang kembali** — setelah pergi minimal 5 menit (game ditutup atau
  diminimalkan), panel ringkasan menampilkan lama pergi dan apa yang terjadi:
  urusan yang terisi, rekrut gratis siap, hari/event baru, pesan chat aliansi,
  hasil perang guild, musim arena, dan hadiah peringkat. Hadiah login menyusul.
- **Penasihat** — 13 penasihat dengan 4 atribut dan 3 kelangkaan (Langka, Epik,
  Legenda); latih dengan perak. Batas level ditentukan jabatan.
- **Skill & ikatan penasihat** — tiap penasihat punya skill pasif (mis. hasil pajak,
  korban kampanye, kekuatan tempur, biaya latih) yang menguat dengan bintang; 5
  ikatan memberi bonus tambahan bila semua anggotanya dimiliki. Kekuatan tempur
  (dengan skill) dipakai di arena, bos aliansi, dan perang.
- **Rekrut (gacha)** — tarik x1 (100 emas) atau x10 (900 emas, dijamin minimal
  satu Epik), plus 1 rekrut gratis tiap 24 jam. Peluang Legenda 4% / Epik 21% /
  Langka 75%, dengan jaminan Legenda paling lambat di tarikan ke-50. Duplikat
  menambah bintang (maks. 5, +20% atribut per bintang); setelah penuh menjadi
  perak. 6 penasihat (termasuk 2 Legenda) hanya bisa didapat lewat rekrut.
  Emas didapat dari kampanye (bonus tiap tahap ke-5) dan naik jabatan.
- **Perang visual otomatis** — tahap besar kampanye (tiap tahap ke-5), Menara
  Ujian, Arena, dan serangan benteng perang aliansi ditayangkan sebagai perang:
  dua barisan prajurit saling menyerbu 3 ronde, tiga penasihat terkuat meneriakkan
  jurusnya, korban berjatuhan sesuai hasil. Hasil dihitung model lebih dulu
  (`GameModel.battle_plan` hanya membagi sisa pasukan per ronde), jadi tombol
  Lewati dan Kecepatan ×2 tidak mengubah hasil. Pengaturan "Lewati tayangan
  perang" menampilkan hasil langsung. Formasi (Seimbang, Serbu, Bertahan) dipilih
  di halaman Kampanye dan memberi bonus kecil dengan kelemahan.
- **Festival musiman** — Pesta Tahun Baru (28 Des–7 Jan), Berkah Ramadan &
  Lebaran (awal Ramadan sampai sepekan setelah Idulfitri, tanggal per tahun di
  `FESTIVALS`), Pesta Kemerdekaan (10–24 Agu), Semangat Sumpah Pemuda (24 Okt–2 Nov),
  dan Hari Pahlawan (5–16 Nov). Tiap festival punya token sendiri dari hadiah harian
  dan 6 tugas, toko festival (emas, tiket, batu bintang, pusaka), dan bingkai profil
  khusus. Token hangus saat festival selesai.
- **Kota yang tumbuh** — Keraton, Pasar, Lumbung, dan Barak naik level (maks 10)
  dengan perak dan waktu pembangunan (satu pembangunan sekaligus, bisa dipercepat
  dengan emas). Bonus hasil urusan per level; Keraton dibatasi jabatan dan
  membatasi bangunan lain. Gambar bangunan di banner Kota berubah dari tanah
  kosong, bangunan sederhana, sampai megah (aset `assets/buildings/`).
- **Ekspedisi** — dari Tahap 3, kirim penasihat ke Hutan Alas Purwo (1 jam),
  Candi Borobudur (2 jam), Pelabuhan Sunda Kelapa (4 jam), atau Gunung Merapi
  (8 jam). Hadiah ditentukan saat berangkat dan makin besar bila atribut penasihat
  cocok dengan tujuan. 2 rombongan sekaligus (3 sejak Gubernur), dengan notifikasi
  saat kembali.
- **Kuda tunggangan** — dari Tahap 12, Kandang Kuda di halaman Penasihat: Kuda
  Jawa dan Gayo (perak), Sandel dan Bima (emas), serta Kuda Sembrani bersayap.
  Kuda yang ditunggangi menambah semua atribut penunggangnya 4–12% (+1% per level,
  maks level 10); naik level dengan pakan (pangan).
- **Cerita bercabang** — di akhir bab 1, 3, 5, dan 7 Tuan memilih jalan (mis.
  mengampuni begal atau menghukumnya, berdamai dengan Panglima Lalim atau
  menyerbu bentengnya). Tiap pilihan memberi hadiah berbeda, bonus permanen kecil
  (hasil urusan, kekuatan tempur, atau prestise), dan dialog bab berikutnya
  mengikuti pilihan itu. Keputusan yang sudah diambil tampil di panel cerita.
- **Kampanye** — tahap tanpa batas yang dibuat prosedural. Kekuatan total
  menentukan berapa prajurit yang gugur. Menang memberi perak, prestise & emas serta
  membuka penasihat/selir baru.
- **Misi harian** — 5 misi acak tiap hari dari 10 jenis (urusan kota, latih
  penasihat, menang kampanye, kunjungi selir, didik anak, rekrut, dll.),
  direset tengah malam waktu setempat. Tiap misi memberi emas + sumber daya dan
  20 poin aktivitas; 3 peti aktivitas terbuka di 40/80/100 poin. Tombol Misi di
  header menampilkan lencana jumlah hadiah yang siap diklaim, dan tombol "Pergi"
  langsung membuka menu terkait.
- **Aliansi** — terbuka setelah Tahap 5; pilih Garuda Nusantara, Teratai Emas,
  atau Macan Kumbang. Sumbangan harian (3x) menaikkan level aliansi (bonus hasil
  urusan kota +3% per level) dan memberi Jasa; Toko Aliansi menukar Jasa dengan
  emas & sumber daya; bos mingguan Buto Ijo (3 serangan/hari, hadiah untuk semua
  yang ikut menyerang); daftar anggota dan kabar aliansi. Anggota lain saat ini
  disimulasikan offline (NPC yang tumbuh, menyumbang, dan menyerang bos tiap hari)
  karena belum ada server; logika simulasinya terkumpul di bagian "Aliansi" pada
  `game_model.gd` agar mudah diganti dengan data server.
- **Tas & item** — tombol Tas di menu Kota: Tiket Rekrut, Batu Bintang, Gulungan
  Latihan, Pil Keakraban, Teh Semangat (isi penuh urusan), dan peti sumber daya.
  Item bertarget memakai pemilih penasihat/selir. Item didapat dari tahap besar
  kampanye, peti aktivitas, hadiah login, event, toko aliansi/arena, dan fitur lain.
- **Leaderboard global** — tombol Peringkat di header: kategori Kekuatan,
  Kampanye, Prestise, Arena, dan Aliansi. Peringkat Anda di antara 100.001 pemain
  (mis. "#12.345 · Top 12,3%"), 50 teratas dengan tag aliansi dan medali, serta
  hadiah mingguan berdasarkan persentil Kekuatan (Top 1% = 300 emas). Server saat
  ini disimulasikan: nilai pemain lain mengikuti distribusi statistik yang tumbuh
  seiring umur akun, sehingga peringkat naik saat Anda makin kuat.
- **Chat aliansi** — sub-tab Chat di Aliansi: gelembung pesan dengan avatar,
  jabatan, dan jam; ketik bebas atau pakai 4 pesan cepat. Anggota NPC mengobrol
  sendiri (juga saat game ditutup) sesuai keadaan aliansi (HP bos, skor perang,
  event, tips), membalas pesan Anda sesuai topiknya dalam beberapa detik, dan
  bereaksi saat Anda menyumbang/menyerang bos/merebut benteng. Filter kata kasar,
  batas 120 huruf, jeda 2 detik antar pesan, dan lencana pesan belum dibaca.
- **Perang aliansi** — sub-tab Perang di Aliansi: perang mingguan (Senin-Minggu)
  melawan aliansi lain yang bergiliran. Masing-masing punya 5 benteng; Keraton
  Inti (300 poin) baru bisa diserang setelah 3 benteng lain direbut. NPC kedua
  pihak menyerang tiap hari; pemain punya 3 serangan/hari (+VIP) untuk memilih
  benteng dan mengumpulkan jasa perang. Skor dari benteng yang direbut/dirusak;
  menang 300 emas + 500 jasa, kalah 100 emas + 150 jasa, plus bonus jasa perang.
- **Arena PvP** — terbuka setelah Tahap 8. Poin arena (mulai 1000, sistem Elo)
  menentukan liga Perunggu/Perak/Emas/Berlian/Legenda. 5 tiket per hari (+ beli
  dengan emas), pilih 1 dari 3 lawan, pertarungan animasi 3 ronde dengan peluang
  menang dari perbandingan kekuatan. Koin arena untuk Toko Arena, musim mingguan
  dengan hadiah sesuai liga, papan peringkat, dan catatan pertahanan. Lawan saat
  ini adalah "pemain" simulasi offline (bagian "Arena" di `game_model.gd`).
- **Event mingguan** — 5 event bergiliran tiap Senin: Festival Panen (sawah +50%),
  Turnamen Ksatria (korban -20%), Pasar Malam (pajak +50%), Pesta Istana (peluang
  anak +15%), Ritual Purnama (Legenda 4% → 7%). Poin event dari aksi sesuai tema
  dan +50 per misi harian yang diklaim; 7 tingkat hadiah sampai 3000 poin (total
  660 emas). Banner event di menu Kota dan label bonus di menu yang terpengaruh.
- **Hadiah login harian** — kalender 7 hari dengan hadiah yang makin besar
  (Hari 7: 300 emas + 5000 prajurit). Harus berturut-turut: terlewat sehari
  kembali ke Hari 1. Muncul otomatis saat game dibuka bila belum diklaim, dan
  bisa dibuka lewat tombol Login di header.
- **Istana** — kunjungi selir untuk menaikkan keakraban (menambah Karisma) dan
  peluang mendapat anak. Didik anak dengan pangan (jeda 30 menit per anak), lalu nikahkan untuk bonus
  atribut permanen ke penasihat.
- **Istana: Anak, Penjara, Perjamuan** — anak dewasa bisa ikut Ujian Negara dan
  menjadi pejabat (Juru Tulis s.d. Menteri Muda, bonus permanen hasil urusan kota);
  tahanan dari kampanye diinterogasi (Interogasi/Gertak) sampai mengaku untuk perak,
  prestise, dan item; Jamuan Sederhana/Pesta Agung harian dan undangan perjamuan
  dari tuan lain untuk prestise.
- **Jabatan** — 6 tingkat; menaikkan batas charge, pengali hasil, batas level,
  dan kursi anak.
- **Toko & pembelian dalam aplikasi** — buka lewat tombol "+" di chip Emas atau
  dari halaman Rekrut. Paket Pemula (sekali beli, termasuk penasihat Epik), Kartu
  Bulanan (300 emas + 100 emas/hari selama 30 hari), dan 5 paket emas dengan bonus
  x2 untuk pembelian pertama. Setiap transaksi hanya diproses sekali, pembelian
  tertunda dipulihkan otomatis, dan ada tombol "Pulihkan Pembelian". Lihat bagian
  "Pembelian dalam aplikasi" di bawah untuk mengaktifkan Google Play Billing.
- **VIP** — poin VIP dari pembelian (1 poin per Rp1.000) dan +1 tiap klaim login
  harian. VIP 1–10 memberi hasil urusan kota +2% per level, kapasitas urusan &
  energi kunjungan +1 s.d. +3, tiket arena, sumbangan aliansi, dan serangan bos
  tambahan; hadiah harian VIP; hadiah naik level; dan Paket Hadiah VIP sekali beli
  dengan emas (termasuk penasihat Epik/Legenda). Ketuk avatar di header untuk
  membuka panel VIP.
- **Cerita & misi utama** — 6 bab dari Kepala Desa sampai Perdana Menteri, tiap
  bab dibuka dengan dialog bergambar dan berisi 3-4 misi berbasis pencapaian
  (tahap, kekuatan, jabatan, anak, aliansi, arena, pejabat, bintang) dengan hadiah
  per misi dan hadiah tamat bab. Pelacak misi utama ada di menu Kota.
- **Tutorial pemain baru** — 14 langkah dipandu penasihat Sekar Pandita: layar
  digelapkan kecuali tombol yang diajarkan (bingkai emas + panah), dan langkah
  berikutnya muncul setelah pemain benar-benar melakukan aksinya. Hadiah 100 emas
  + 2000 perak; bisa dilewati (tanpa hadiah). Pengenalan fitur muncul sekali saat
  Aliansi/Arena terbuka, dan menu Panduan di Kota merangkum semua fitur. Save
  lama otomatis dianggap sudah selesai tutorial.
- **Grafis** — potret untuk 7 penasihat, 4 selir, anak (laki-laki/perempuan),
  avatar Tuan, dan 4 jenderal musuh; ikon sumber daya; latar bergambar tiap menu
  (gerbang candi bentar, pendopo, medan perang, istana); motif batik kawung;
  font Cinzel & Nunito. Animasi angka hadiah, serangan, dan pop-up hasil.
- **Suara & musik** — musik latar bernuansa gamelan (saron, bonang, gong,
  kendang, suling) yang berganti per menu: Kota/Penasihat (slendro tenang),
  Kampanye (irama perang), Istana (pelog lembut), dengan crossfade. Efek suara
  untuk setiap aksi (koin, panen, rekrut, latih, serang, menang/kalah, kunjungan,
  kelahiran, naik jabatan). Volume musik & efek suara diatur di Pengaturan.
- **Simpan otomatis** ke `user://save.json` (tiap 15 detik, saat keluar, dan
  saat aplikasi di-minimize di HP).

## Struktur

```
project.godot              Konfigurasi (portrait 720x1280, renderer mobile)
scenes/main.tscn           Scene utama
scripts/core/game_data.gd  Data & angka balancing (jabatan, penasihat, tahap)
scripts/core/game_model.gd Semua logika game, tanpa UI (mudah diuji)
scripts/core/game.gd       Autoload "Game": simpan/muat & autosave
scripts/core/settings.gd   Autoload "Settings": volume, hemat baterai, notifikasi
scripts/core/notifier.gd   Autoload "Notifier": notifikasi lokal Android (via plugin)
scripts/core/ads.gd        Autoload "Ads": iklan video berhadiah (AdMob / mode uji)
scripts/core/play_games.gd Autoload "PlayGames": pencapaian & save cloud Google Play Games
scripts/core/telemetry.gd  Autoload "Telemetry": statistik lokal & deteksi crash
scripts/core/i18n.gd       Autoload "I18n": pilihan bahasa (Otomatis/Indonesia/English)
scripts/core/pattern_translation.gd  Penerjemah kamus + templat (lihat "Bahasa")
translations/en.tsv        Kamus bahasa Inggris
scripts/core/audio.gd      Autoload "Audio": musik latar & efek suara
scripts/core/store.gd      Autoload "Store": Google Play Billing / Mode Uji
scripts/ui/main.gd         UI dibangun lewat kode (header, 4 halaman, navigasi bawah)
scripts/ui/ui_theme.gd     Tema visual (warna, tombol, kartu, font)
scripts/ui/art.gd          Pemuat gambar (PNG diutamakan, lalu SVG)
scripts/ui/tutorial_layer.gd  Lapisan tutorial (sorotan, dialog, panah)
assets/portraits|icons|bg  Gambar karakter, ikon, latar (SVG)
assets/audio               Musik & efek suara (OGG)
assets/fonts               Font Cinzel & Nunito (lisensi SIL OFL)
tools/gen_art.py           Generator semua gambar SVG
tools/gen_audio.py         Generator musik & efek suara (numpy + ffmpeg)
tools/sim_economy.gd       Bot simulasi ekonomi N hari (lihat docs/balance.md)
tools/gen_launcher_icons.gd Ikon peluncur Android & Play Store dari icon.svg
tools/make_keystore.sh     Membuat keystore rilis
tools/i18n_extract.gd      Daftar teks yang belum ada di kamus terjemahan
tools/i18n_check.tscn      Pemeriksa cakupan terjemahan (menjelajah UI + bot)
docs/                      Penyeimbangan, kebijakan privasi, Data Safety, checklist rilis
tools/build_android.sh     Build APK
tests/run_tests.gd         Tes logika headless
```

## Grafis

Semua gambar dibuat oleh `tools/gen_art.py` dari bentuk vektor sederhana, jadi
orisinal (bebas hak cipta pihak lain), tajam di semua layar, dan APK tetap
kecil. Ubah warna, rambut, hiasan kepala, atau pakaian karakter di kamus
`CHARACTERS` lalu jalankan:

```bash
python3 tools/gen_art.py
```

Mau pakai gambar buatan ilustrator? Taruh file PNG dengan nama yang sama
(misalnya `assets/portraits/arya.png`, persegi, disarankan 512×512) dan game
otomatis memakainya menggantikan SVG.

Logika dipisah dari UI, sehingga nanti UI bisa diganti dengan scene buatan
desainer (gambar, animasi) tanpa mengubah aturan game, dan logika yang sama bisa
dipindahkan ke server.

## Suara & musik

Semua audio dibuat oleh `tools/gen_audio.py` dengan sintesis suara instrumen
gamelan (bilah logam berpartial tak harmonis dengan efek "ombak", gong dengan
dengung panjang, kendang, suling), jadi orisinal dan bebas royalti. Ubah
balungan (melodi inti), tempo, atau tangga nada lalu jalankan:

```bash
python3 tools/gen_audio.py   # butuh numpy dan ffmpeg (libvorbis)
```

Untuk memakai musik dari komposer, timpa file `assets/audio/*.ogg` dengan nama
yang sama. Musik otomatis di-loop.

## Menjalankan

1. Unduh [Godot 4.3+](https://godotengine.org/download) (versi standar, bukan .NET).
2. Buka Godot → **Import** → pilih `project.godot` → **Run** (F5).

Menjalankan tes:

```bash
godot --headless --path . --import
godot --headless --path . --script res://tests/run_tests.gd
```

## Build Android (APK)

Proyek sudah berisi preset ekspor **Android** (`export_presets.cfg`):
package `com.microaltech.toplordlike`, arm64-v8a + armeabi-v7a, layar portrait
penuh (immersive). Progres otomatis tersimpan saat tombol Back ditekan atau
aplikasi di-minimize.

Persiapan sekali saja:

1. Di Godot: **Editor → Manage Export Templates → Download and Install** (4.3).
2. Pasang Android SDK (cukup *build-tools* dan *platform-tools*, misalnya lewat
   Android Studio) dan JDK 17+.
3. **Editor → Editor Settings → Export → Android**: isi `Android SDK Path`,
   `Java SDK Path`, dan `Debug Keystore` (buat dengan perintah di bawah bila
   belum ada).

```bash
keytool -genkeypair -v -keystore debug.keystore -storepass android \
  -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 \
  -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
```

Build lewat editor: **Project → Export → Android → Export Project**, atau
lewat terminal:

```bash
GODOT=/path/ke/godot tools/build_android.sh           # build/top-lord-like-debug.apk
GODOT=/path/ke/godot tools/build_android.sh release   # APK release
adb install -r build/top-lord-like-debug.apk          # pasang ke HP via USB
```

Untuk rilis, buat keystore release sendiri, simpan baik-baik (kalau hilang
aplikasi tidak bisa di-update di Play Store), dan isi lewat environment variable
`GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER`,
`GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`. Google Play mewajibkan format
**AAB**: aktifkan `gradle_build/use_gradle_build`, set `export_format` ke AAB,
lalu **Project → Install Android Build Template**.

## Notifikasi lokal (Android)

Saat game ditinggalkan, `Notifier` menjadwalkan pengingat dari
`GameModel.notification_plan()`: urusan kota penuh, energi kunjungan penuh,
rekrut gratis siap, hadiah login esok pukul 09.00, dan pengingat setelah 2 hari
tidak bermain. Saat game dibuka lagi, semua jadwal dibatalkan. Pemain bisa
mematikannya di Pengaturan; di Android 13+ izin notifikasi diminta saat pertama
kali dibuka.

Godot 4.3 tidak punya notifikasi lokal bawaan, jadi dipakai plugin Android kecil
`TlgNotify` (Java, AlarmManager + BroadcastReceiver):

1. Build AAR (butuh Android SDK dan akses ke Maven Google/Central):
   ```bash
   cd plugins/tlg_notify_android
   gradle assembleRelease
   mkdir -p ../../addons/tlg_notify/bin
   cp build/outputs/aar/tlg_notify-release.aar ../../addons/tlg_notify/bin/
   ```
2. Di Godot: **Project → Install Android Build Template**, lalu di preset
   Android centang **Gradle Build → Use Gradle Build**.
3. Ekspor seperti biasa. Addon `addons/tlg_notify` menyertakan AAR secara
   otomatis.

Tanpa AAR, ekspor tetap berjalan seperti sebelumnya (tanpa notifikasi) dan semua
pemanggilan `Notifier` aman. **Catatan:** kode plugin belum dikompilasi atau diuji
di perangkat karena lingkungan pengembangan ini tidak bisa mengakses Maven Google.
Uji di HP sungguhan sebelum rilis.

## Bahasa (Indonesia & English)

Game tersedia dalam bahasa Indonesia dan Inggris. Pilihannya ada di
**Pengaturan → Bahasa / Language**: Otomatis (mengikuti bahasa perangkat), Bahasa
Indonesia, atau English. Bahasa bisa diganti kapan saja tanpa memulai ulang.

Teks sumber di kode tetap bahasa Indonesia, sedangkan terjemahan ada di
`translations/en.tsv` (format `sumber<TAB>terjemahan[<TAB>konteks]`).
`PatternTranslation` diterapkan otomatis ke semua Label/Button:
- Teks berformat dikenali dari templatnya, misalnya `Hasil +%d %s · dari %s` atau
  `Halo, {player}!`. Argumennya ikut diterjemahkan (Perak → Silver), sedangkan
  nama orang dibiarkan.
- Pesan gabungan dipecah per kalimat atau per butir daftar.

Save menyimpan teks sumber, sehingga log, chat, dan gelar yang tersimpan ikut
berganti bahasa. Nama diri (penasihat, selir, aliansi, NPC) sengaja tidak
diterjemahkan.

Alur saat menambah atau mengubah teks:

```bash
# 1. Daftar teks yang belum ada di kamus -> build/i18n/missing_en.tsv
godot --headless --path . --script res://tools/i18n_extract.gd -- en
# 2. Isi terjemahannya, salin ke translations/en.tsv
# 3. Jelajahi semua layar + bot dalam bahasa Inggris; laporkan sisa teks Indonesia
xvfb-run godot --path . res://tools/i18n_check.tscn -- en     # keluar kode 1 bila ada sisa
```

Tes otomatis memeriksa bahwa setiap templat terjemahan memakai placeholder
yang sama dan tidak ada kunci ganda. Untuk bahasa lain: buat
`translations/<kode>.tsv`, daftarkan di `I18n.LANGUAGES`, lalu jalankan kedua alat
di atas dengan kode bahasa tersebut.

## Rilis ke Google Play

- `tools/make_keystore.sh` membuat keystore rilis dan menampilkan environment
  variable yang perlu di-set.
- Preset **Android AAB (Play Store)** menghasilkan `.aab` lewat Gradle build:
  `tools/build_android.sh aab`. Preset ini butuh Android Build Template, yang
  tidak bisa diuji di lingkungan pengembangan ini karena Maven Google diblokir.
  APK rilis biasa sudah diuji, dan tanda tangannya terverifikasi dengan
  keystore buatan skrip.
- Ikon peluncur (termasuk ikon adaptif) dibuat dari `icon.svg` oleh
  `tools/gen_launcher_icons.gd`.
- **Statistik & crash lokal**: `Telemetry` mencatat sesi, lama bermain, dan aksi
  di perangkat. Bila game berhenti tiba-tiba, ekor log sesi itu disimpan, lalu
  pemain bisa menyalin laporannya dari **Pengaturan → Salin Laporan**. Tidak ada
  data yang dikirim ke internet.
- Dokumen: `docs/privacy_policy.md`, `docs/play_data_safety.md`,
  `docs/release_checklist.md`.

Untuk fitur online sungguhan (aliansi, chat, arena, perang, dan peringkat antar
pemain), lihat rancangan di `docs/server_design.md`: Nakama, akun dan migrasi
save, peta fitur dari simulasi ke server, model data, anti-curang, biaya, dan
fase pengerjaan.

## Pembelian dalam aplikasi

`scripts/core/store.gd` punya tiga mode:

| Mode | Kapan | Perilaku |
|---|---|---|
| Google Play Billing | Plugin `GodotGooglePlayBilling` terpasang di build Android | Pembayaran sungguhan lewat Google Play |
| Mode Uji | Build debug tanpa plugin (editor, APK debug) | Pembayaran disimulasikan, ditandai "MODE UJI" |
| Tidak tersedia | Build rilis tanpa plugin | Tombol beli dinonaktifkan (mencegah emas gratis) |

Mengaktifkan pembayaran sungguhan:

1. Unduh plugin dari <https://github.com/godotengine/godot-google-play-billing> (versi
   yang cocok dengan Godot 4.3), lalu **Project → Install Android Build Template** dan
   pasang plugin sesuai petunjuknya. Aktifkan `gradle_build/use_gradle_build` dan
   centang plugin di preset ekspor Android. Izin BILLING ditambahkan oleh plugin.
2. Di Google Play Console buat produk dalam aplikasi dengan ID yang sama seperti
   `IAP_PRODUCTS` di `game_data.gd`: `starter_pack`, `monthly_card`, `gold_60`,
   `gold_330`, `gold_680`, `gold_1380`, `gold_3280`. Harga di game diambil dari
   Google Play (harga di `game_data.gd` hanya cadangan tampilan).
3. Uji di jalur **Internal testing** dengan akun penguji lisensi sebelum rilis.

Catatan penting:
- `store.gd` ditulis mengikuti API plugin v1 (`startConnection`, `querySkuDetails`,
  `purchase`, `consumePurchase`, `acknowledgePurchase`, `queryPurchases`) dan **belum
  diuji di perangkat** karena butuh akun Play Console. Bila versi plugin yang dipakai
  berbeda, sesuaikan nama method/sinyal di bagian "Callback Google Play Billing".
- Untuk mencegah kecurangan, idealnya token pembelian diverifikasi di server
  (Google Play Developer API) sebelum hadiah diberikan. Game ini belum punya server,
  jadi verifikasi masih di perangkat.

## Langkah berikutnya

- Uji di HP sungguhan: plugin notifikasi `TlgNotify`, plugin Google Play Billing,
  dan build AAB (tidak bisa diuji di lingkungan pengembangan ini).
- Backend online sesuai `docs/server_design.md`, mulai dari fase 0 (akun dan
  validasi IAP), lalu fase 1 (aliansi, chat, peringkat sungguhan).
- Konten lanjutan: penasihat dan selir baru, banner rekrut *rate-up*, toko event,
  iklan berhadiah (AdMob), serta bab cerita setelah Perdana Menteri.
