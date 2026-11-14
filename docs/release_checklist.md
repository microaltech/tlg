# Checklist Rilis Google Play

## Sekali di awal

- [ ] Buat keystore rilis: `tools/make_keystore.sh`. Simpan file dan kata sandinya
      di dua tempat aman. Aktifkan **Play App Signing** di Play Console agar
      kunci unggahan bisa diganti bila hilang.
- [ ] Di Godot: **Project → Install Android Build Template** (dibutuhkan preset
      AAB dan plugin).
- [ ] ID paket: `com.microaltech.tuannusantara` (`package/unique_name` di kedua preset).
      ID ini **tidak bisa diubah** setelah rilis pertama.
- [ ] Hosting `docs/privacy_policy.md` di URL publik, lalu isi nama pengembang,
      email, dan tanggal.
- [ ] Buat produk IAP di Play Console dengan ID yang sama seperti `IAP_PRODUCTS`
      di `game_data.gd`. Pasang plugin GodotGooglePlayBilling (lihat bagian
      "Pembelian dalam aplikasi" di README).
- [ ] (Opsional) Build plugin notifikasi `plugins/tlg_notify_android`, lalu uji
      di HP Android 13+.
- [ ] (Opsional) Mode online: hosting `server/` dengan HTTPS, jadwalkan peninjauan
      laporan chat, isi Data Safety bagian mode online, lalu beri tahu pemain alamat
      servernya.
- [ ] Buat juga produk IAP `costume_raja` (sekali beli, Rp49.000).
- [ ] Buat juga produk IAP `season_pass`, `offer_promote`, dan `offer_rescue`
      (semuanya consumable).
- [ ] Iklan: pasang plugin AdMob, ganti `REWARDED_UNIT_ID` di
      `scripts/core/ads.gd`, tambahkan App ID AdMob ke manifest, lalu perbarui
      Data Safety (lihat `docs/play_data_safety.md`).
- [ ] Google Play Games: aktifkan Play Games Services, buat 43 pencapaian (satu
      per tingkat), isi `ACHIEVEMENT_IDS` di `scripts/core/play_games.gd`, dan
      aktifkan Saved Games untuk cadangan cloud.

## Setiap rilis

- [ ] Festival Ramadan & Lebaran: cocokkan tanggal di `FESTIVALS` (`game_data.gd`)
      dengan pengumuman resmi Kemenag untuk tahun berjalan, dan tambahkan tahun
      berikutnya bila daftar akan habis (saat ini sampai 2030).

1. [ ] Naikkan `version/code` (bilangan bulat, wajib selalu naik) dan
       `version/name` di **kedua** preset `export_presets.cfg`, serta
       `application/config/version` di `project.godot`.
2. [ ] Jalankan tes: `godot --headless --path . --script res://tests/run_tests.gd`.
   Bila ada teks baru, jalankan juga `tools/i18n_extract.gd` dan
   `tools/i18n_check.tscn` (lihat bagian "Bahasa" di README) sampai keduanya
   melaporkan 0 teks tersisa.
3. [ ] Bila angka ekonomi berubah, jalankan
       `godot --headless --path . --script res://tools/sim_economy.gd -- 30 4 1`
       lalu bandingkan dengan `docs/balance.md`.
4. [ ] Set environment keystore (`GODOT_ANDROID_KEYSTORE_RELEASE_*`).
5. [ ] Build: `GODOT=/path/ke/godot tools/build_android.sh aab`. Butuh Android Build
       Template terpasang, **JDK 17** (Godot 4.3 menolak Java 21; set
       `export/android/java_sdk_path` di Editor Settings ke JDK 17), Android SDK
       platform 34 + build-tools 34, dan akses internet ke repositori Google Maven
       (dl.google.com) serta Maven Central untuk Gradle. Bila Maven Central
       membalas 429 (terlalu banyak permintaan), tunggu semenit lalu ulangi;
       unduhan yang sudah selesai tersimpan di cache Gradle.
5b. [ ] Semua preset Android memakai Gradle build agar plugin TlgNotify (notifikasi,
       bagikan, pemantau server) ikut. Bila Java plugin diubah, bangun ulang AAR
       (lihat README, bagian Plugin Android TlgNotify).
5c. [ ] Bila server dipakai: set `ADMIN_TOKEN`, `IAP_PACKAGE`, dan
       `IAP_SERVICE_ACCOUNT` (lihat `server/README.md`).
5d. [ ] Naikkan `version/code` di ketiga preset **dan** `Data.VERSION_CODE`
       (game_data.gd) bersamaan. Setelah versi baru tersedia di Play, naikkan
       `min_version` di dasbor hanya bila versi lama harus berhenti dipakai.
5e. [ ] CI hijau, termasuk "Uji tampilan" (unduh artifact tangkapan-layar-ui dan lihat
       sekilas halaman dalam 3 bahasa).
5f. [ ] Server: `docs/deploy.md` (HTTPS, ADMIN_TOKEN, cadangan, UptimeRobot ke /status).
6. [ ] Uji APK rilis di minimal satu HP sungguhan
       (`tools/build_android.sh release`). Periksa: tutorial, gulir layar,
       pembelian di jalur Internal testing dengan akun penguji lisensi,
       notifikasi, ringkasan "Selamat datang kembali", dan simpan/muat setelah
       aplikasi ditutup paksa.
7. [ ] Unggah AAB ke **Internal testing**, lalu Closed testing, lalu Production.
       Langkah Internal testing:
       a. Play Console → Create app (nama "Tuan Nusantara", Game, Gratis).
       b. Setup → App integrity → **Play App Signing**: biarkan Google membuat kunci
          aplikasi; keystore Anda menjadi *upload key*.
       c. Testing → Internal testing → Testers: buat daftar email penguji (maks. 100).
       d. Create new release → unggah `build/tuan-nusantara.aab` (versi rilis, bukan
          `-debug`; Play menolak AAB yang ditandatangani kunci debug) → isi catatan
          rilis → Review → Start rollout.
       e. Bagikan tautan "Join on the web" ke penguji; uji dengan
          `docs/test_checklist.md` di beberapa HP.
8. [ ] Lengkapi listing toko: ikon 512 px (`assets/launcher/play_store_512.png`),
       feature graphic 1024×500 dan 6 tangkapan layar ponsel 1080×1920 (buat
       dengan `tools/store_assets.gd`, hasil di `build/store/`), teks dari
       `docs/store_listing.md`, kategori Strategi.
9. [ ] Periksa **App content**: Data safety (`docs/play_data_safety.md`),
       rating konten, target audiens, dan iklan.

## Setelah rilis

- [ ] Pantau **Android vitals** (crash & ANR) di Play Console. Minta pemain yang
      melapor masalah memakai **Pengaturan → Salin Laporan**, lalu menempelkan
      hasilnya ke email.
- [ ] Simpan tag git untuk setiap versi yang dirilis, mis. `git tag v0.1.0`.
