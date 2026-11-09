# Performa

Diukur dengan `tools/perf_check.gd` di komputer pengembang (Godot 4.3, renderer
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

## Yang masih bisa diperbaiki

- **Terjemahan pertama kali (bahasa Inggris).** Halaman Penasihat butuh 286 ms saat
  pertama dibuka karena tiap teks dinamis dicocokkan dengan templat kamus. Setelah
  itu cache terjemahan membuatnya 40 ms. Bila terasa tersendat di HP, cache bisa
  dipanaskan saat layar pembuka, atau teks dinamis bisa diterjemahkan per bagian
  (`tr()` pada potongan tetap) alih-alih seluruh kalimat.
