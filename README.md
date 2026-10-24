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
- **Penasihat** — 7 penasihat dengan 4 atribut; latih dengan perak. Batas level
  ditentukan jabatan.
- **Kampanye** — tahap tanpa batas yang dibuat prosedural. Kekuatan total
  menentukan berapa prajurit yang gugur. Menang memberi perak & prestise serta
  membuka penasihat/selir baru.
- **Istana** — kunjungi selir untuk menaikkan keakraban (menambah Karisma) dan
  peluang mendapat anak. Didik anak dengan pangan, lalu nikahkan untuk bonus
  atribut permanen ke penasihat.
- **Jabatan** — 6 tingkat; menaikkan batas charge, pengali hasil, batas level,
  dan kursi anak.
- **Grafis** — potret untuk 7 penasihat, 4 selir, anak (laki-laki/perempuan),
  avatar Tuan, dan 4 jenderal musuh; ikon sumber daya; latar bergambar tiap menu
  (gerbang candi bentar, pendopo, medan perang, istana); motif batik kawung;
  font Cinzel & Nunito. Animasi angka hadiah, serangan, dan pop-up hasil.
- **Simpan otomatis** ke `user://save.json` (tiap 15 detik, saat keluar, dan
  saat aplikasi di-minimize di HP).

## Struktur

```
project.godot              Konfigurasi (portrait 720x1280, renderer mobile)
scenes/main.tscn           Scene utama
scripts/core/game_data.gd  Data & angka balancing (jabatan, penasihat, tahap)
scripts/core/game_model.gd Semua logika game, tanpa UI (mudah diuji)
scripts/core/game.gd       Autoload "Game": simpan/muat & autosave
scripts/ui/main.gd         UI dibangun lewat kode (header, 4 halaman, navigasi bawah)
scripts/ui/ui_theme.gd     Tema visual (warna, tombol, kartu, font)
scripts/ui/art.gd          Pemuat gambar (PNG diutamakan, lalu SVG)
assets/portraits|icons|bg  Gambar karakter, ikon, latar (SVG)
assets/fonts               Font Cinzel & Nunito (lisensi SIL OFL)
tools/gen_art.py           Generator semua gambar SVG
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

## Langkah berikutnya

- Aset visual: potret penasihat/selir, latar kota, ikon sumber daya, animasi.
- Gacha/rekrut penasihat, item & inventaris, misi harian, event.
- Backend + akun, PvP, aliansi, leaderboard.
- IAP (Google Play Billing) & iklan berhadiah (AdMob) lewat plugin Godot.
