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

## Setiap rilis

1. [ ] Naikkan `version/code` (bilangan bulat, wajib selalu naik) dan
       `version/name` di **kedua** preset `export_presets.cfg`, serta
       `application/config/version` di `project.godot`.
2. [ ] Jalankan tes: `godot --headless --path . --script res://tests/run_tests.gd`.
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
