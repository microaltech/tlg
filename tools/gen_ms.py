#!/usr/bin/env python3
"""Buat translations/ms.tsv (Bahasa Melayu) dari teks sumber bahasa Indonesia.

Bahasa Melayu sangat dekat dengan bahasa Indonesia, jadi terjemahan dibuat dengan
mengganti kata yang berbeda (mis. "gratis" -> "percuma", "kirim" -> "hantar",
"pejabat" -> "pegawai"). Hasilnya terjemahan *beta*: mudah dipahami pembaca Malaysia
dan Brunei, tetapi sebaiknya ditinjau penutur asli sebelum rilis resmi. Koreksi manual
ditulis di translations/ms_override.tsv (sumber<TAB>terjemahan) dan selalu menang.

    python3 tools/gen_ms.py
"""
import os
import re

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
SRC = os.path.join(ROOT, "translations", "en.tsv")  # kolom pertama = teks sumber (Indonesia)
OUT = os.path.join(ROOT, "translations", "ms.tsv")
OVERRIDE = os.path.join(ROOT, "translations", "ms_override.tsv")

# Kata Indonesia -> Melayu (huruf kecil; kapitalisasi mengikuti teks asli).
WORDS = {
    # umum
    "gratis": "percuma", "bisa": "boleh", "dapat": "dapat", "sudah": "sudah", "belum": "belum",
    "berhasil": "berjaya", "gagal": "gagal", "coba": "cuba", "dicoba": "dicuba", "mencoba": "mencuba",
    "kirim": "hantar", "dikirim": "dihantar", "mengirim": "menghantar", "terkirim": "dihantar", "kirimkan": "hantarkan",
    "hapus": "padam", "dihapus": "dipadam", "menghapus": "memadam",
    "karena": "kerana", "saja": "sahaja", "sampai": "sehingga", "silakan": "sila", "mulai": "mula",
    "dimulai": "dimulakan", "memulai": "memulakan", "lewati": "langkau", "dilewati": "dilangkau",
    "lanjut": "teruskan", "lanjutkan": "teruskan", "menit": "minit", "detik": "saat", "jam": "jam",
    "teman": "rakan", "pertemanan": "persahabatan", "pesan": "mesej", "pengaturan": "tetapan",
    "notifikasi": "pemberitahuan", "perangkat": "peranti", "layar": "skrin", "ponsel": "telefon",
    "bagikan": "kongsi", "dibagikan": "dikongsi", "membagikan": "berkongsi", "berbagi": "berkongsi",
    "bergabung": "menyertai", "gabung": "sertai", "dukung": "sokong", "mendukung": "menyokong",
    "tas": "beg", "kantong": "beg", "uang": "wang", "rusak": "rosak", "otomatis": "automatik",
    "kualitas": "kualiti", "aktivitas": "aktiviti", "komunitas": "komuniti", "fasilitas": "kemudahan",
    "versi": "versi", "aplikasi": "aplikasi", "kualifikasi": "kelayakan", "selamat": "selamat",
    "tunggu": "tunggu", "pakai": "guna", "dipakai": "digunakan", "memakai": "menggunakan", "terpakai": "digunakan",
    "ganti": "tukar", "diganti": "ditukar", "mengganti": "menukar", "tukar": "tukar",
    "beli": "beli", "membeli": "membeli", "ambil": "ambil", "diambil": "diambil",
    "kartu": "kad", "pas": "pas", "paket": "pakej", "diskon": "diskaun", "harga": "harga",
    "berikutnya": "seterusnya", "selanjutnya": "seterusnya", "sekarang": "sekarang", "nanti": "nanti",
    "kalah": "kalah", "menang": "menang", "pertarungan": "pertarungan", "terbuka": "terbuka",
    "kunci": "kunci", "terkunci": "dikunci", "buka": "buka", "tutup": "tutup", "batal": "batal",
    "hasil": "hasil", "kerjakan": "laksanakan", "dikerjakan": "dilaksanakan", "mengerjakan": "melaksanakan",
    "rekrut": "rekrut", "prajurit": "askar", "pangan": "makanan", "sawah": "sawah",
    "pejabat": "pegawai", "jabatan": "jawatan", "naik": "naik", "kantor": "pejabat",
    "aturan": "peraturan", "kebijakan": "dasar", "rumah sakit": "hospital", "pertandingan": "perlawanan",
    "tim": "pasukan", "rapat": "mesyuarat", "acara": "acara", "musim": "musim", "liga": "liga",
    "kalender": "kalendar", "minggu": "minggu", "bulan": "bulan", "tahun": "tahun",
    "sore": "petang", "kemarin": "semalam", "besok": "esok", "nanti malam": "malam nanti",
    "bagus": "bagus", "hebat": "hebat", "sempurna": "sempurna", "lezat": "sedap", "enak": "sedap",
    "lumayan": "boleh tahan", "agak": "agak", "cukup": "cukup", "kurang": "kurang",
    "tidak": "tidak", "jangan": "jangan", "harus": "mesti", "perlu": "perlu", "wajib": "wajib",
    "dipilih": "dipilih", "pilih": "pilih", "tekan": "tekan", "ketuk": "ketik", "geser": "leret",
    "gulir": "tatal", "sentuh": "sentuh", "salin": "salin", "disalin": "disalin", "tempel": "tampal",
    "tempelkan": "tampalkan", "simpan": "simpan", "disimpan": "disimpan", "cadangan": "sandaran",
    "pulihkan": "pulihkan", "dipulihkan": "dipulihkan", "masuk": "masuk", "keluar": "keluar",
    "putuskan": "putuskan", "sambungkan": "sambungkan", "tersambung": "bersambung", "menyambungkan": "menyambung",
    "server": "pelayan", "daring": "dalam talian", "luring": "luar talian", "online": "dalam talian",
    "offline": "luar talian", "unduh": "muat turun", "diunduh": "dimuat turun", "unggah": "muat naik",
    "diunggah": "dimuat naik", "perbarui": "kemas kini", "pembaruan": "kemas kini", "diperbarui": "dikemas kini",
    "laporan": "laporan", "masalah": "masalah", "bantuan": "bantuan", "panduan": "panduan",
    "kebijakan privasi": "dasar privasi", "statistik": "statistik", "getar": "getaran",
    "tetap": "tetap", "lagi": "lagi", "juga": "juga", "hanya": "hanya", "semua": "semua", "setiap": "setiap",
    "tiap": "setiap", "banyak": "banyak", "sedikit": "sedikit", "baru": "baharu", "lama": "lama",
    "anak": "anak", "selir": "gundik", "istana": "istana", "kerajaan": "kerajaan", "kota": "bandar",
    "perkotaan": "bandar", "desa": "kampung", "kepala desa": "ketua kampung", "camat": "penghulu",
    "pasukan": "pasukan", "perang": "perang", "serang": "serang", "menyerang": "menyerang",
    "bos": "bos", "hadiah": "hadiah", "emas": "emas", "perak": "perak", "item": "item", "barang": "barang",
    "toko": "kedai", "pasar": "pasar", "dagangan": "dagangan", "pedagang": "peniaga", "saudagar": "saudagar",
    "jual": "jual", "dijual": "dijual", "menjual": "menjual", "pajak": "cukai", "biaya": "kos",
    "bayar": "bayar", "dibayar": "dibayar", "kecil": "kecil", "besar": "besar", "ekstra": "ekstra",
    "nyala": "hidup", "mati": "mati", "malam": "malam", "siang": "siang", "pagi": "pagi",
    "tampilan": "paparan", "ditampilkan": "dipaparkan", "menampilkan": "memaparkan", "tampil": "dipapar",
    "ukuran": "saiz", "warna": "warna", "suara": "bunyi", "musik": "muzik", "efek": "kesan",
    "kecepatan": "kelajuan", "cepat": "cepat", "lambat": "perlahan", "tayangan": "tayangan",
    "kekuatan": "kekuatan", "kecerdasan": "kecerdasan", "politik": "politik", "karisma": "karisma",
    "keakraban": "keakraban", "bakat": "bakat", "latih": "latih", "dilatih": "dilatih", "melatih": "melatih",
    "didik": "didik", "dewasa": "dewasa", "menikah": "berkahwin", "nikah": "kahwin", "pernikahan": "perkahwinan",
    "dinikahkan": "dikahwinkan", "ekspedisi": "ekspedisi", "perburuan": "perburuan", "berburu": "memburu",
    "kuda": "kuda", "pacuan": "lumba", "kebun": "kebun", "panen": "tuai", "dipanen": "dituai",
    "masak": "masak", "dapur": "dapur", "hidangan": "hidangan", "bahan": "bahan",
    "kuis": "kuiz", "jawab": "jawab", "benar": "betul", "salah": "salah", "soal": "soalan",
    "pertanyaan": "soalan", "sejarah": "sejarah", "wilayah": "wilayah", "peta": "peta",
    "tahap": "peringkat", "lantai": "tingkat", "menara": "menara", "ujian": "ujian",
    "peringkat": "kedudukan", "papan peringkat": "papan pendahulu", "arena": "arena",
    "aliansi": "pakatan", "anggota": "ahli", "sumbangan": "sumbangan", "kode": "kod",
    "undangan": "jemputan", "undang": "jemput", "diundang": "dijemput", "pemain": "pemain",
    "akun": "akaun", "masukkan": "masukkan", "alamat": "alamat", "kosongkan": "kosongkan",
}

SPECIAL = [  # frasa dulu, sebelum kata tunggal
    ("Tidak bisa", "Tidak boleh"), ("tidak bisa", "tidak boleh"), ("Hari Ini", "Hari Ini"),
    ("Kepala Desa", "Ketua Kampung"), ("kepala desa", "ketua kampung"),
]


def match_case(src, word):
    if src.isupper():
        return word.upper()
    if src[:1].isupper():
        return word[:1].upper() + word[1:]
    return word


WORD_RE = re.compile(r"[A-Za-z]+")


def translate(text):
    for a, b in SPECIAL:
        text = text.replace(a, b)

    def sub(m):
        w = m.group(0)
        rep = WORDS.get(w.lower())
        return match_case(w, rep) if rep else w

    # Jangan ubah placeholder (%s, %d, %%) dan escape (\\n, \\").
    parts = re.split(r"(%[-+0-9.]*[sdif%]|\\.)", text)
    return "".join(p if i % 2 else WORD_RE.sub(sub, p) for i, p in enumerate(parts))


def main():
    overrides = {}
    if os.path.exists(OVERRIDE):
        for line in open(OVERRIDE, encoding="utf-8"):
            if "\t" in line and not line.startswith("#"):
                k, v = line.rstrip("\n").split("\t", 1)
                overrides[k] = v
    out = ["# Bahasa Melayu (beta) — dibuat oleh tools/gen_ms.py dari teks sumber Indonesia.",
           "# Jangan diedit langsung; koreksi ditulis di translations/ms_override.tsv."]
    seen = set()
    for line in open(SRC, encoding="utf-8"):
        line = line.rstrip("\n")
        if not line or line.startswith("#") or "\t" not in line:
            continue
        src = line.split("\t", 1)[0]
        if src in seen:
            continue
        seen.add(src)
        out.append("%s\t%s" % (src, overrides.get(src, translate(src))))
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")
    print("ms.tsv: %d teks" % (len(out) - 2))


if __name__ == "__main__":
    main()
