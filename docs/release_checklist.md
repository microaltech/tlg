# Checklist Rilis Google Play

## Sekali di awal

- [ ] Buat keystore rilis: `tools/make_keystore.sh`. Simpan file dan kata sandinya
      di dua tempat aman. Aktifkan **Play App Signing** di Play Console agar
      kunci unggahan bisa diganti bila hilang.
- [ ] Di Godot: **Project → Install Android Build Template** (dibutuhkan preset
      AAB dan plugin).
- [ ] Ganti `package/unique_name` (`com.microaltech.toplordlike`) bila perlu.
      Nama ini **tidak bisa diubah** setelah rilis pertama.
- [ ] Hosting `docs/privacy_policy.md` di URL publik, lalu isi nama pengembang,
      email, dan tanggal.
- [ ] Buat produk IAP di Play Console dengan ID yang sama seperti `IAP_PRODUCTS`
      di `game_data.gd`. Pasang plugin GodotGooglePlayBilling (lihat bagian
      "Pembelian dalam aplikasi" di README).
- [ ] (Opsional) Build plugin notifikasi `plugins/tlg_notify_android`, lalu uji
      di HP Android 13+.
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
5. [ ] Build: `GODOT=/path/ke/godot tools/build_android.sh aab`.
6. [ ] Uji APK rilis di minimal satu HP sungguhan
       (`tools/build_android.sh release`). Periksa: tutorial, gulir layar,
       pembelian di jalur Internal testing dengan akun penguji lisensi,
       notifikasi, ringkasan "Selamat datang kembali", dan simpan/muat setelah
       aplikasi ditutup paksa.
7. [ ] Unggah AAB ke **Internal testing**, lalu Closed testing, lalu Production.
8. [ ] Lengkapi listing toko: ikon 512 px (`assets/launcher/play_store_512.png`),
       feature graphic 1024×500, minimal 2 tangkapan layar ponsel, deskripsi
       singkat dan lengkap, kategori Strategi.
9. [ ] Periksa **App content**: Data safety (`docs/play_data_safety.md`),
       rating konten, target audiens, dan iklan.

## Setelah rilis

- [ ] Pantau **Android vitals** (crash & ANR) di Play Console. Minta pemain yang
      melapor masalah memakai **Pengaturan → Salin Laporan**, lalu menempelkan
      hasilnya ke email.
- [ ] Simpan tag git untuk setiap versi yang dirilis, mis. `git tag v0.1.0`.
