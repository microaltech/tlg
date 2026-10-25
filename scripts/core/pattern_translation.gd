extends Translation
## Terjemahan berbasis kamus dari teks sumber (bahasa Indonesia) ke satu bahasa.
##
## Semua Label/Button Godot otomatis memanggil tr() pada teksnya, jadi UI cukup
## menyimpan teks Indonesia apa adanya. Kelas ini menerjemahkan:
## 1. teks persis yang ada di kamus;
## 2. teks hasil format dari templat di kamus, mis. "Hasil +%d %s · dari %s" atau
##    "Halo, {player}!": bagian tetapnya diterjemahkan, argumen %s/{nama} ikut
##    diterjemahkan bila ada di kamus (mis. "Perak" -> "Silver"), angka dibiarkan;
## 3. pesan gabungan ("Menang ... emas. Rampasan: X."): dipecah per kalimat,
##    per baris, atau per " · ", lalu tiap bagian diterjemahkan.
## Teks yang tidak dikenal (nama orang, ketikan pemain) dikembalikan apa adanya.
##
## Kamus: file TSV "sumber<TAB>terjemahan[<TAB>konteks]", \n dan \t ditulis sebagai
## escape. Konteks membedakan teks sumber yang sama dengan arti berbeda, mis.
## "Kekuatan" sebagai atribut (Strength) dan sebagai kekuatan total (konteks "power").
## Templat terjemahan harus memakai placeholder % dengan urutan yang sama;
## placeholder {nama} boleh berpindah urutan.

const CACHE_MAX := 4000
const MAX_DEPTH := 6
## Isi argumen teks (boleh kosong), dalam tiga tingkat. Argumen tidak pernah
## melintasi akhir kalimat, agar templat umum seperti "Benteng %s" atau "+%d %s"
## tidak menelan kalimat atau butir daftar lain.
const ARG_MODES := {
	"strict": "((?:(?![.!?:] |\\n| · |, |; | \\+ ).)*?)",
	"medium": "((?:(?![.!?] (?!·)|\\n|, |; | \\+ ).)*?)",
	"loose": "((?:(?![.!?] (?!·)|\\n).)*?)",
}
## Tingkat longgar hanya untuk templat "wadah": bagian tetapnya berisi pemisah
## daftar/kalimat, atau %s terakhirnya diikuti tanda penutup (mis. "Hadiah %s: %s.").
const LIST_MARKS := [", ", "; ", ". ", "! ", "? ", " · ", " + "]
const CLOSING_MARKS := [".", "!", ")", "\""]

var _exact := {}
## Templat per kunci awalan (2 huruf pertama bagian tetap; "" bila diawali placeholder).
var _buckets := {}
var _cache := {}
## konteks -> PatternTranslation berisi entri khusus konteks itu
var _contexts := {}
var _placeholder := RegEx.create_from_string("%%|%[-+0 #]*\\d*(?:\\.\\d+)?[dfsx]|\\{[a-z_]+\\}")
var _splitter := RegEx.create_from_string("(?<=[.!?])\\s+|\\n| · | \\| |; |, | \\+ ")
## "angka kata" dan "kata angka" (mis. "+500 pangan", "Karisma 59", "Ketua  03:19").
var _num_words := RegEx.create_from_string("^([-+]?\\d[\\d.,:]*(?:Rb|Jt|Mlr)?%?)(\\s+)(\\D.*)$")
var _words_num := RegEx.create_from_string("^(.*\\D)(\\s+)([-+x]?\\d[\\d.,:/]*%?)$")
## Tepi yang dikupas sebelum mencoba lagi: spasi dan butir daftar.
var _edges := RegEx.create_from_string("^([\\s•·]*)(.*?)([\\s•·]*)$")
var _short_number := RegEx.create_from_string("^([-+]?[\\d.]+)(Rb|Jt|Mlr)$")
var _letters := RegEx.create_from_string("[A-Za-z]")


## Muat kamus TSV. Mengembalikan jumlah entri.
func load_tsv(path: String) -> int:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_warning("Kamus terjemahan kosong atau tidak ditemukan: %s" % path)
		return 0
	var count := 0
	for line in text.split("\n"):
		if line.is_empty() or line.begins_with("#"):
			continue
		var cols := line.split("\t")
		if cols.size() < 2 or cols[1].is_empty():
			continue
		if cols.size() >= 3 and cols[2] != "":
			if not _contexts.has(cols[2]):
				_contexts[cols[2]] = get_script().new()
			_contexts[cols[2]].add_entry(cols[0].c_unescape(), cols[1].c_unescape())
		else:
			add_entry(cols[0].c_unescape(), cols[1].c_unescape())
		count += 1
	return count


func add_entry(src: String, dst: String) -> void:
	_cache.clear()
	if _placeholder.search(src) == null:
		_exact[src] = dst
		return
	var pattern := _compile(src, dst)
	if pattern.is_empty():
		_exact[src] = dst  # hanya %% di dalam teks
		return
	# Kelompokkan per 2 huruf awal bila templat diawali bagian tetap.
	var key := src.substr(0, 2) if _placeholder.search(src).get_start() >= 2 else ""
	if not _buckets.has(key):
		_buckets[key] = []
	_buckets[key].append(pattern)


func _get_message(src_message: StringName, context: StringName) -> StringName:
	var src := String(src_message)
	if context != &"" and _contexts.has(String(context)):
		var hit: String = _contexts[String(context)].translate_text(src)
		if hit != src:
			return StringName(hit)
	return StringName(translate_text(src))


func translate_text(text: String, depth := 0) -> String:
	if text.is_empty() or _letters.search(text) == null:
		return text
	if _cache.has(text):
		return _cache[text]
	var out := _translate(text, depth)
	# Hanya hasil tingkat teratas yang disimpan: hasil di kedalaman lebih dalam
	# bisa terpotong oleh MAX_DEPTH dan tidak boleh dipakai ulang di tempat lain.
	if depth == 0:
		if _cache.size() >= CACHE_MAX:
			_cache.clear()
		_cache[text] = out
	return out


func _translate(text: String, depth: int) -> String:
	if _exact.has(text):
		return _exact[text]
	var hit := _match_pattern(text, depth)
	if hit != "":
		return hit
	var m := _short_number.search(text)
	if m:
		return m.get_string(1) + {"Rb": "K", "Jt": "M", "Mlr": "B"}[m.get_string(2)]
	var e := _edges.search(text)
	if e and e.get_string(2) != text and e.get_string(2) != "":
		return e.get_string(1) + translate_text(e.get_string(2), depth) + e.get_string(3)
	var parts := _split(text)
	if parts.size() > 1:
		return _translate_parts(parts, depth) if depth < MAX_DEPTH else text
	# Aturan angka hanya untuk satu segmen, bukan daftar/kalimat gabungan.
	var nw := _num_words.search(text)
	if nw:
		var words := translate_text(nw.get_string(3), depth + 1)
		if words != nw.get_string(3):
			return translate_text(nw.get_string(1), depth + 1) + nw.get_string(2) + words
	var wn := _words_num.search(text)
	if wn:
		var words := translate_text(wn.get_string(1), depth + 1)
		if words != wn.get_string(1):
			return words + wn.get_string(2) + wn.get_string(3)
	return text


## Terjemahkan [bagian, pemisah, ...] secara serakah: dari tiap posisi, cari
## gabungan bagian terpanjang yang cocok dengan kamus (templat bisa berisi
## beberapa kalimat), lalu lanjut setelahnya.
func _translate_parts(parts: Array, depth: int) -> String:
	var out := ""
	var k := 0
	while k < parts.size():
		var done := false
		var j := parts.size() - 1
		while j > k:
			var chunk := "".join(parts.slice(k, j + 1)).strip_edges()
			var hit: String = _exact.get(chunk, "")
			if hit == "":
				hit = _match_pattern(chunk, depth + 1)
			if hit != "":
				out += hit
				k = j + 1
				done = true
				break
			j -= 2
		if not done:
			out += translate_text(parts[k], depth + 1)
			k += 1
		if k < parts.size():
			out += parts[k]  # pemisah
			k += 1
	return out


## Pecah menjadi [bagian, pemisah, bagian, ...].
func _split(text: String) -> Array:
	var parts := []
	var pos := 0
	for m in _splitter.search_all(text):
		parts.append(text.substr(pos, m.get_start() - pos))
		parts.append(m.get_string())
		pos = m.get_end()
	parts.append(text.substr(pos))
	return parts


## Pilih templat terbaik: yang menyisakan paling sedikit argumen teks tak
## terterjemahkan, lalu tingkat pencocokan paling ketat, lalu bagian tetap terpanjang.
func _match_pattern(text: String, depth: int) -> String:
	var candidates: Array = _buckets.get(text.substr(0, 2), []) + _buckets.get("", [])
	var best := ""
	var best_score := -INF
	for level in 2:
		var mode: String = ["strict", "medium"][level]
		for p in candidates:
			var m: RegExMatch = p[mode].search(text)
			if m == null:
				continue
			var r := _apply(p, m, depth)
			var score: float = -1000.0 * r[1] - 100.0 * level + p["weight"]
			if score > best_score:
				best_score = score
				best = r[0]
	if best_score > -INF:
		return best
	candidates.sort_custom(func(a, b): return a["weight"] > b["weight"])
	for p in candidates:
		if not p["container"]:
			continue
		var m: RegExMatch = p["loose"].search(text)
		if m:
			return _apply(p, m, depth)[0]
	return ""


## Isi templat terjemahan dari hasil regex. Mengembalikan [teks, jumlah argumen
## teks yang tidak berubah setelah diterjemahkan].
func _apply(p: Dictionary, m: RegExMatch, depth: int) -> Array:
	var values := {}
	var pct := []
	var misses := 0
	for i in p["slots"].size():
		var slot: String = p["slots"][i]
		var value := m.get_string(i + 1)
		if slot == "%s" or slot.begins_with("{"):
			var translated := translate_text(value, depth + 1)
			if translated == value and _letters.search(value) != null:
				misses += 1
			value = translated
		if slot.begins_with("{"):
			values[slot] = value
		else:
			pct.append(value)
	return [_fill(p["dst"], pct, values), misses]


func _fill(template: String, pct: Array, named: Dictionary) -> String:
	var out := ""
	var pos := 0
	var i := 0
	for m in _placeholder.search_all(template):
		out += template.substr(pos, m.get_start() - pos)
		var token := m.get_string()
		if token == "%%":
			out += "%"
		elif token.begins_with("{"):
			out += str(named.get(token, token))
		else:
			out += str(pct[i]) if i < pct.size() else token
			i += 1
		pos = m.get_end()
	return out + template.substr(pos)


## Ubah templat sumber menjadi regex. Kosong bila templat tidak berguna
## (hanya placeholder dan spasi, mis. "%s %s", yang akan memotong teks sembarangan).
func _compile(src: String, dst: String) -> Dictionary:
	var regex := {"strict": "^", "medium": "^", "loose": "^"}
	var slots := []
	var literal := ""
	var pos := 0
	for m in _placeholder.search_all(src):
		var lit := src.substr(pos, m.get_start() - pos)
		for k in regex:
			regex[k] += _escape(lit)
		literal += lit
		var token := m.get_string()
		var text_arg := token.begins_with("{") or token.ends_with("s")
		for k in regex:
			if token == "%%":
				regex[k] += "%"
			elif text_arg:
				regex[k] += ARG_MODES[k]
			else:
				regex[k] += "([-+]?\\d[\\d.,]*)"
		if token == "%%":
			literal += "%"
		else:
			slots.append(token if token.begins_with("{") else ("%s" if text_arg else "%d"))
		pos = m.get_end()
	var tail := src.substr(pos)
	for k in regex:
		regex[k] += _escape(tail) + "$"
	literal += tail
	if slots.is_empty() or literal.strip_edges() == "":
		return {}
	var container := false
	for mark in LIST_MARKS:
		container = container or literal.contains(mark)
	if _letters.search(literal) != null:  # bukan templat umum seperti "%s (%s)"
		for mark in CLOSING_MARKS:
			container = container or src.ends_with("%s" + mark)
	return {"strict": RegEx.create_from_string(regex["strict"]), "medium": RegEx.create_from_string(regex["medium"]),
		"loose": RegEx.create_from_string(regex["loose"]), "container": container, "slots": slots, "dst": dst, "weight": literal.length()}


static func _escape(s: String) -> String:
	var out := ""
	for ch in s:
		if ch in "\\^$.|?*+()[]{}":
			out += "\\"
		out += ch
	return out
