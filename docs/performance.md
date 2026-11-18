# Performa

Diukur dengan `tools/perf_check.gd` di komputer pengembang (Godot 4.3 pada pengukuran awal; 4.7.2 sejak November 2026, renderer
Compatibility, xvfb, layar 720x1280). HP kelas bawah biasanya 3–6 kali lebih lambat.

    xvfb-run -s "-screen 0 720x1280x24" godot --path . --resolution 720x1280 \
        --script res://tools/perf_check.gd -- id

## Hasil (tahap 30, save uji)

| Halaman | Node | Bahasa Indonesia, pertama / berikutnya | Bahasa Inggris, pertama / berikutnya |
|---|---|---|---|
| Kota | 177 | 48 / 39 ms | 68 / 60 ms |
| Penasihat | 323 | 49 / 44 ms | 286 / 40 ms |
| Rekrut | 149 | 18 / 16 ms | 58 / 12 ms |
| Kampanye | 61 | 16 / 14 ms | 60 / 11 ms |
| Istana | 58 | 12 / 12 ms | 16 / 9 ms |

Muat adegan utama: sekitar 1 detik. Memori statis: sekitar 80 MB.

## Perbaikan yang sudah dilakukan

- **Potret dan ikon dimuat di thread latar** saat game dibuka (`Art.warm_up()`),
  sehingga halaman Penasihat pertama kali dibuka turun dari 123 ms ke 49 ms.
- **Kartu penasihat dibatasi 6** sebelum tombol "Tampilkan Semua Penasihat".
- **Memo perhitungan** (`GameModel.memo_begin/memo_end`): atribut, kekuatan, dan
  hasil urusan dihitung sekali per pembangunan halaman.
- Hanya halaman yang terlihat yang dibangun ulang (sudah ada sejak sebelumnya).

## Pengukuran November 2026 (setelah batch 11)

| Halaman (bahasa Inggris, pertama dibuka) | Sebelum | Sesudah |
|---|---|---|
| Penasihat | 284 ms | 127–145 ms |
| Kampanye | 247 ms | 82–91 ms |
| Rekrut | 124 ms | 38–47 ms |
| Arena | 73 ms | 37 ms |

Penyebab: penerjemah berpola menggabungkan dan mengurutkan ulang daftar templat pada
setiap pencarian. Sekarang daftar per awalan disimpan sekali (`_candidates`) dan templat
disaring dengan potongan teks tetapnya sebelum regex dijalankan. Bahasa Indonesia tidak
berubah (tanpa terjemahan): 9–45 ms per halaman. Muat adegan utama sekitar 1,2–1,4 detik.

## Yang masih bisa diperbaiki

- **Halaman Penasihat dalam bahasa Inggris** masih 127+ ms saat pertama dibuka (347
  node). Bisa dipercepat dengan memanaskan cache terjemahan di layar pembuka, atau
  menerjemahkan potongan tetap (`tr()` per bagian) alih-alih seluruh kalimat dinamis.
