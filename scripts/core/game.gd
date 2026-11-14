extends Node
## Autoload "Game": memegang GameModel, memuat/menyimpan ke user://, autosave.

const Model := preload("res://scripts/core/game_model.gd")
const SAVE_PATH := "user://save.json"
const AUTOSAVE_SECONDS := 15.0

var model := Model.new()
var _autosave := 0.0
## Keadaan saat pemain terakhir pergi (lihat GameModel.away_snapshot).
var _away_snap := {}
## Ringkasan "Selamat datang kembali" yang belum ditampilkan UI; kosong = tidak ada.
var away := {}

signal returned


func _ready() -> void:
	model.rng.randomize()
	# Misi harian direset pada tengah malam waktu setempat (bias dalam menit).
	model.tz_bias = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	if debug_enabled():
		var cfg := ConfigFile.new()
		if cfg.load(DEBUG_PATH) == OK:
			time_offset = maxf(0.0, float(cfg.get_value("debug", "time_offset", 0.0)))
	load_game()


## Mode uji cepat (hanya build debug): geser jam game ke depan untuk menguji
## pengisian ulang, hari baru, dan acara tanpa menunggu. Disimpan di user://debug.cfg
## agar waktu tidak mundur saat game dibuka lagi.
const DEBUG_PATH := "user://debug.cfg"
var time_offset := 0.0


func now() -> float:
	return Time.get_unix_time_from_system() + time_offset


func debug_enabled() -> bool:
	return OS.is_debug_build() and not OS.has_feature("template_release")


func debug_advance(seconds: float) -> void:
	if not debug_enabled():
		return
	time_offset += seconds
	var cfg := ConfigFile.new()
	cfg.set_value("debug", "time_offset", time_offset)
	cfg.save(DEBUG_PATH)
	model.sync(now())
	model.changed.emit()


func _process(delta: float) -> void:
	_autosave += delta
	if _autosave >= AUTOSAVE_SECONDS:
		_autosave = 0.0
		save_game()


func _notification(what: int) -> void:
	# Simpan saat aplikasi ditutup, tombol Back Android, atau di-minimize.
	if what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST,
			NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		_away_snap = model.away_snapshot(now())
		save_game()
	elif what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN]:
		_check_return()


func _check_return() -> void:
	if _away_snap.is_empty():
		return
	model.sync(now())
	var report: Dictionary = model.away_report(_away_snap, now())
	_away_snap = {}
	if not report.is_empty():
		Telemetry.mark("ringkasan kembali")
		away = report
		returned.emit()


const BACKUP_PATH := "user://save.bak"
## Penanda bahwa save bertanda tangan sudah pernah ditulis: setelah itu save tanpa
## tanda tangan (format lama) tidak diterima lagi.
const SIGNED_FLAG := "user://save_signed.flag"
## Pesan untuk pemain bila save diubah di luar game (ditampilkan main.gd sekali).
var load_notice := ""


func save_game() -> void:
	var data: Dictionary = model.to_dict()
	data["away"] = _away_snap if not _away_snap.is_empty() else model.away_snapshot(now())
	var text: String = model.signed_text(data)
	# Save sah terakhir disimpan sebagai cadangan sebelum ditimpa.
	if FileAccess.file_exists(SAVE_PATH):
		var prev := FileAccess.get_file_as_string(SAVE_PATH)
		if not model.verify_signed(prev).is_empty():
			var b := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
			if b:
				b.store_string(prev)
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Gagal menyimpan: %s" % FileAccess.get_open_error())
		return
	f.store_string(text)
	if not FileAccess.file_exists(SIGNED_FLAG):
		var flag := FileAccess.open(SIGNED_FLAG, FileAccess.WRITE)
		if flag:
			flag.store_string("1")


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		model.new_game(now())
		return
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	var data: Dictionary = model.verify_signed(text)
	if data.is_empty() and text.begins_with("{") and not FileAccess.file_exists(SIGNED_FLAG):
		var legacy = JSON.parse_string(text)  # save lama sebelum ada tanda tangan
		data = legacy if legacy is Dictionary else {}
	if data.is_empty():
		var backup := model.verify_signed(FileAccess.get_file_as_string(BACKUP_PATH)) \
			if FileAccess.file_exists(BACKUP_PATH) else {}
		load_notice = "Save diubah di luar game sehingga tidak bisa dipakai. Progres dipulihkan dari cadangan terakhir." \
			if not backup.is_empty() else "Save rusak atau diubah di luar game. Permainan dimulai dari awal."
		push_warning(load_notice)
		data = backup
	if data.has("version"):
		model.from_dict(data, now())
		away = model.away_report(data.get("away", {}), now())
	else:
		model.new_game(now())


## Kode cadangan dari progres saat ini (untuk disalin pemain).
func export_code() -> String:
	return model.encode_save(model.to_dict())


## Pulihkan progres dari kode cadangan. Mengembalikan hasil {ok, msg}.
func import_code(code: String) -> Dictionary:
	var data: Dictionary = model.decode_save(code)
	if data.is_empty():
		return {"ok": false, "msg": "Kode cadangan tidak valid."}
	model.from_dict(data, now())
	save_game()
	return {"ok": true, "msg": "Progres berhasil dipulihkan."}


func reset_game() -> void:
	model.new_game(now())
	save_game()
