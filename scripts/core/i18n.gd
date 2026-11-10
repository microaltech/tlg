extends Node
## Autoload "I18n": memasang terjemahan bahasa Inggris dan memilih bahasa
## sesuai Settings.language ("auto", "id", "en", "ms").
##
## Teks sumber game adalah bahasa Indonesia. Untuk menambah bahasa lain, buat
## translations/<kode>.tsv dan daftarkan di LANGUAGES.

const PatternTranslation := preload("res://scripts/core/pattern_translation.gd")

## kode -> nama bahasa (ditulis dalam bahasanya sendiri, tidak diterjemahkan)
const LANGUAGES := {"id": "Bahasa Indonesia", "en": "English", "ms": "Bahasa Melayu (beta)"}

var _translations: Array = []


func _ready() -> void:
	for code in LANGUAGES:
		var path := "res://translations/%s.tsv" % code
		if not FileAccess.file_exists(path):
			continue
		var t := PatternTranslation.new()
		t.locale = code
		t.load_tsv(path)
		TranslationServer.add_translation(t)
		_translations.append(t)
	apply()
	Settings.changed.connect(apply)


func _exit_tree() -> void:
	# Translation berbasis skrip harus dilepas sebelum keluar (mencegah crash Godot).
	for t in _translations:
		TranslationServer.remove_translation(t)
	_translations.clear()


## Bahasa yang aktif setelah "auto" diselesaikan.
func current() -> String:
	var lang: String = Settings.language
	if lang == "auto" or not LANGUAGES.has(lang):
		var sys := OS.get_locale_language()
		lang = "ms" if sys == "ms" else ("id" if sys in ["id", "in"] else "en")
	return lang


func apply() -> void:
	var lang := current()
	if TranslationServer.get_locale() != lang:
		TranslationServer.set_locale(lang)
