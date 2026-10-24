extends Node
## Autoload "Game": memegang GameModel, memuat/menyimpan ke user://, autosave.

const Model := preload("res://scripts/core/game_model.gd")
const SAVE_PATH := "user://save.json"
const AUTOSAVE_SECONDS := 15.0

var model := Model.new()
var _autosave := 0.0


func _ready() -> void:
	model.rng.randomize()
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
		save_game()


func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Gagal menyimpan: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(model.to_dict()))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		model.new_game(now())
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if data is Dictionary:
		model.from_dict(data, now())
	else:
		push_warning("Save rusak, memulai game baru.")
		model.new_game(now())


func reset_game() -> void:
	model.new_game(now())
	save_game()
