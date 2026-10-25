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
	load_game()


func now() -> float:
	return Time.get_unix_time_from_system()


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
		away = report
		returned.emit()


func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Gagal menyimpan: %s" % FileAccess.get_open_error())
		return
	var data: Dictionary = model.to_dict()
	data["away"] = _away_snap if not _away_snap.is_empty() else model.away_snapshot(now())
	f.store_string(JSON.stringify(data))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		model.new_game(now())
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if data is Dictionary:
		model.from_dict(data, now())
		away = model.away_report(data.get("away", {}), now())
	else:
		push_warning("Save rusak, memulai game baru.")
		model.new_game(now())


func reset_game() -> void:
	model.new_game(now())
	save_game()
