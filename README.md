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
  Politik), Rekrut Prajurit (dari Karisma). Tiap urusan memakai *charge* yang
  terisi 1 per 60 detik, tetap terisi saat game ditutup (offline progress).
- **Penasihat** — 13 penasihat dengan 4 atribut dan 3 kelangkaan (Langka, Epik,
  Legenda); latih dengan perak. Batas level ditentukan jabatan.
- **Rekrut (gacha)** — tarik x1 (100 emas) atau x10 (900 emas, dijamin minimal
  satu Epik), plus 1 rekrut gratis tiap 24 jam. Peluang Legenda 4% / Epik 21% /
  Langka 75%, dengan jaminan Legenda paling lambat di tarikan ke-50. Duplikat
  menambah bintang (maks. 5, +20% atribut per bintang); setelah penuh menjadi
  perak. 6 penasihat (termasuk 2 Legenda) hanya bisa didapat lewat rekrut.
  Emas didapat dari kampanye (bonus tiap tahap ke-5) dan naik jabatan.
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
  peluang mendapat anak. Didik anak dengan pangan, lalu nikahkan untuk bonus
  atribut permanen ke penasihat.
- **Jabatan** — 6 tingkat; menaikkan batas charge, pengali hasil, batas level,
  dan kursi anak.
- **Toko & pembelian dalam aplikasi** — buka lewat tombol "+" di chip Emas atau
  dari halaman Rekrut. Paket Pemula (sekali beli, termasuk penasihat Epik), Kartu
  Bulanan (300 emas + 100 emas/hari selama 30 hari), dan 5 paket emas dengan bonus
  x2 untuk pembelian pertama. Setiap transaksi hanya diproses sekali, pembelian
  tertunda dipulihkan otomatis, dan ada tombol "Pulihkan Pembelian". Lihat bagian
  "Pembelian dalam aplikasi" di bawah untuk mengaktifkan Google Play Billing.
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
  kelahiran, naik jabatan). Musik & suara bisa dimatikan di menu Kota.
- **Simpan otomatis** ke `user://save.json` (tiap 15 detik, saat keluar, dan
  saat aplikasi di-minimize di HP).

## Struktur

```
project.godot              Konfigurasi (portrait 720x1280, renderer mobile)
scenes/main.tscn           Scene utama
scripts/core/game_data.gd  Data & angka balancing (jabatan, penasihat, tahap)
scripts/core/game_model.gd Semua logika game, tanpa UI (mudah diuji)
scripts/core/game.gd       Autoload "Game": simpan/muat & autosave
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

- Aset visual: potret penasihat/selir, latar kota, ikon sumber daya, animasi.
- Item & inventaris, toko event, papan peringkat online, banner rekrut berganti (rate-up).
- Backend + akun: aliansi & arena online sungguhan (pemain nyata, chat, matchmaking), leaderboard global.
- IAP (Google Play Billing) & iklan berhadiah (AdMob) lewat plugin Godot.
