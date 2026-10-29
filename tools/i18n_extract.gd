extends SceneTree
## Mengumpulkan teks yang tampil ke pemain dan melaporkan yang belum ada di kamus.
##
##   godot --headless --path . --script res://tools/i18n_extract.gd -- [kode-bahasa]
##
## Sumber: konstanta di game_data.gd (dibaca saat runtime, termasuk teks yang
## dirangkai dengan +) dan literal string di skrip game/UI. Hasil:
## build/i18n/missing_<kode>.tsv berisi "teks<TAB><TAB>lokasi" untuk diisi lalu
## disalin ke translations/<kode>.tsv. Tidak ada file yang ditimpa selain itu.

const DATA := "res://scripts/core/game_data.gd"
const CODE := [
	"res://scripts/core/game_data.gd", "res://scripts/core/game_model.gd", "res://scripts/ui/main.gd", "res://scripts/ui/tutorial_layer.gd",
	"res://scripts/core/store.gd", "res://scripts/core/notifier.gd", "res://scripts/core/telemetry.gd",
	"res://scripts/core/game.gd", "res://scripts/core/ads.gd", "res://scripts/core/play_games.gd",
	"res://scripts/core/online.gd",
	"res://scripts/ui/battle_view.gd", "res://scripts/ui/duel_view.gd",
]
## Bidang data yang bukan teks tampilan (ID, ikon, kunci internal).
const SKIP_FIELDS := ["id", "icon", "event", "type", "wait", "target", "speaker", "effect", "rarity", "members",
	"requires", "color", "bg", "emblem", "attr", "dist", "counselor"]
## Konstanta berisi nama diri, ID, atau kata kunci deteksi (bukan teks tampilan).
const SKIP_CONSTS := ["NPC_NAMES", "CHILD_NAMES", "ARENA_AVATARS", "ITEM_ORDER", "STAGE_ITEM_POOL",
	"LB_ALLIANCE_WORDS", "REWARD_KEYS", "ATTRS", "PRISON_CONFESS_ITEMS", "BANQUET_GIFT_ITEMS", "CHAT_BANNED",
	"CHAT_KEYWORDS", "NPC_TITLES"]
## Literal kode yang bukan teks tampilan.
const SKIP_LINE := "push_warning|push_error|print\\(|printerr|assert|\\.connect\\(|has_signal|\\.bus ="
## Nama teknis atau teks yang sengaja tidak diterjemahkan.
const THEME_NAMES := ["Rp", "Content-Type: application/json", "Authorization: Bearer", "AdMob", "Top Lord Like", "GodotPlayGameServices", "ProgressBar", "Button", "ScrollContainer", "LineEdit", "Label", "GodotGooglePlayBilling", "TlgNotify", "Android", "--- log ---","CardLabel", "CardTitle", "TitleLabel", "SmallLabel", "BigLabel", "GoldButton",
	"GreenButton", "NavButton", "DarkPanel", "Chip", "Toast", "Music", "SFX", "Master"]

var found := {}  ## teks -> lokasi
var proper_names := {}
var _lower := RegEx.create_from_string("[a-z]")
var _ident := RegEx.create_from_string("^[a-z_0-9./:%-]+$")
var _capital := RegEx.create_from_string("^[A-Z]")
var _placeholders := RegEx.create_from_string("^(%[-+0-9.]*[dsfx]|\\{[a-z_]+\\}|[\\s,:·/()+\\-%x|])*$")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var lang: String = args[0] if not args.is_empty() else "en"
	var consts: Dictionary = load(DATA).get_script_constant_map()
	for key in ["COUNSELORS", "BEAUTIES", "ALLIANCES"]:
		for d in consts[key]:
			proper_names[d["name"]] = true
	for key in consts:
		if not key in SKIP_CONSTS:
			_walk(consts[key], key, "")
	for path in CODE:
		_scan_code(path)

	var known := {}
	var dict_path := "res://translations/%s.tsv" % lang
	for line in FileAccess.get_file_as_string(dict_path).split("\n"):
		var cols := line.split("\t")
		if cols.size() >= 2 and not line.begins_with("#") and cols[1] != "":
			known[cols[0].c_unescape()] = true
	var missing := []
	for text in found:
		if not known.has(text):
			missing.append("%s\t\t%s" % [text.c_escape(), found[text]])
	DirAccess.make_dir_recursive_absolute("res://build/i18n")
	var out := "res://build/i18n/missing_%s.tsv" % lang
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string("\n".join(missing) + ("\n" if not missing.is_empty() else ""))
	print("%d teks ditemukan, %d sudah diterjemahkan, %d belum -> %s" % [
		found.size(), found.size() - missing.size(), missing.size(), out])
	quit()


func _walk(v, path: String, field: String) -> void:
	match typeof(v):
		TYPE_STRING, TYPE_STRING_NAME:
			var s := String(v)
			if field in SKIP_FIELDS or proper_names.has(s) or not _is_text(s):
				return
			if not found.has(s):
				found[s] = "data:" + path
		TYPE_DICTIONARY:
			for k in v:
				_walk(v[k], path + "." + str(k), str(k))
		TYPE_ARRAY:
			for item in v:
				_walk(item, path, field)


func _scan_code(path: String) -> void:
	var skip := RegEx.create_from_string(SKIP_LINE)
	# "teks" diikuti nol atau lebih  + "lanjutan" (boleh lintas baris dengan \).
	var lit := RegEx.create_from_string("\"((?:[^\"\\\\\\n]|\\\\.)*)\"((?:\\s*\\\\?\\s*\\n?\\s*\\+\\s*\\\\?\\s*\\n?\\s*\"(?:[^\"\\\\\\n]|\\\\.)*\")*)")
	var part := RegEx.create_from_string("\"((?:[^\"\\\\\\n]|\\\\.)*)\"")
	var lines := FileAccess.get_file_as_string(path).split("\n")
	var cleaned := []
	# Untuk game_data.gd, konstanta sudah dibaca saat runtime; ambil hanya literal
	# di dalam fungsi (mis. "Tahap %d" di stage_info).
	var funcs_only := path == DATA
	var in_func := false
	for line in lines:
		if funcs_only:
			if line.begins_with("func ") or line.begins_with("static func "):
				in_func = true
			elif line != "" and not line.begins_with("\t") and not line.begins_with("#"):
				in_func = false
			cleaned.append(_strip_comment(line) if in_func else "")
		else:
			cleaned.append(_strip_comment(line))
	var text := "\n".join(cleaned)
	var starts := PackedInt32Array([0])
	for i in text.length():
		if text.unicode_at(i) == 10:
			starts.append(i + 1)
	for m in lit.search_all(text):
		var line_no := starts.bsearch(m.get_start(), false) - 1
		if skip.search(cleaned[line_no]) != null:
			continue
		var s := m.get_string(1)
		for p in part.search_all(m.get_string(2)):
			s += p.get_string(1)
		s = s.c_unescape().strip_edges()
		if s in THEME_NAMES or not _is_text(s) or _only_placeholders(s):
			continue
		if not found.has(s):
			found[s] = "%s:%d" % [path.get_file(), line_no + 1]


func _is_text(s: String) -> bool:
	if s.begins_with("res://") or s.begins_with("user://"):
		return false
	if _lower.search(s) == null:
		return false
	if _ident.search(s) != null:
		return false  # ID, path, atau kunci
	return s.contains(" ") or _capital.search(s) != null


func _only_placeholders(s: String) -> bool:
	return _placeholders.search(s) != null


func _strip_comment(line: String) -> String:
	var out := ""
	var in_str := false
	var esc := false
	for ch in line:
		if in_str:
			out += ch
			if esc:
				esc = false
			elif ch == "\\":
				esc = true
			elif ch == "\"":
				in_str = false
		else:
			if ch == "#":
				break
			if ch == "\"":
				in_str = true
			out += ch
	return out
