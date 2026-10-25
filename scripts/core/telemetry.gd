extends Node
## Autoload "Telemetry": analitik lokal dan deteksi crash. Semua data hanya
## disimpan di perangkat (user://) dan tidak pernah dikirim ke mana pun.
##
## - Analitik: jumlah sesi, lama bermain, hari aktif, dan hitungan aksi game
##   (dari sinyal GameModel.tracked). Bisa dimatikan di Pengaturan.
## - Crash: file penanda dibuat saat game berjalan dan dihapus saat game
##   dijeda/ditutup dengan normal. Bila penanda masih ada saat game dibuka, sesi
##   sebelumnya berhenti tiba-tiba; ekor log Godot sesi itu disimpan sebagai
##   laporan yang bisa disalin pemain untuk dikirim ke pengembang.

const STATS_PATH := "user://analytics.json"
const CRASH_PATH := "user://crash_reports.json"
const LOCK_PATH := "user://session.lock"
const LOG_DIR := "user://logs"
const MAX_CRASHES := 5
const LOG_TAIL_LINES := 60
## Jumlah log sesi lama yang disimpan. Pemangkasan bawaan Godot 4.3 dimatikan
## (max_log_files besar di project.godot) karena memakai HashSet sehingga bisa
## menghapus log terbaru; Telemetry memangkas sendiri berdasarkan waktu ubah.
const KEEP_LOGS := 8
const SAVE_SECONDS := 60.0

var stats := {}
var crashes: Array = []
var _session_start := 0.0
var _save_timer := 0.0


func _ready() -> void:
	stats = _read_json(STATS_PATH, {})
	crashes = _read_json(CRASH_PATH, [])
	if FileAccess.file_exists(LOCK_PATH):
		_record_crash(FileAccess.get_file_as_string(LOCK_PATH))
	_prune_logs()
	_start_session()
	Game.model.tracked.connect(_on_tracked)


func _process(delta: float) -> void:
	_save_timer += delta
	if _save_timer >= SAVE_SECONDS:
		_save_timer = 0.0
		_flush()


func _exit_tree() -> void:
	_end_session()  # get_tree().quit() juga berarti keluar normal


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			_end_session()
		NOTIFICATION_APPLICATION_RESUMED:
			_start_session()


func _start_session() -> void:
	_session_start = Time.get_unix_time_from_system()
	var f := FileAccess.open(LOCK_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"t": _session_start, "version": _version()}))
	if not Settings.analytics:
		return
	stats["sessions"] = int(stats.get("sessions", 0)) + 1
	stats["first_t"] = float(stats.get("first_t", _session_start))
	var day := Time.get_date_string_from_unix_time(int(_session_start))
	if str(stats.get("last_day", "")) != day:
		stats["last_day"] = day
		stats["active_days"] = int(stats.get("active_days", 0)) + 1
	_flush()


func _end_session() -> void:
	_flush()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LOCK_PATH))


## Tambahkan waktu bermain sejak catatan terakhir lalu simpan.
func _flush() -> void:
	if not Settings.analytics:
		return
	var now := Time.get_unix_time_from_system()
	stats["play_seconds"] = int(stats.get("play_seconds", 0)) + int(now - _session_start)
	_session_start = now
	_write_json(STATS_PATH, stats)


func _on_tracked(event: String) -> void:
	if not Settings.analytics:
		return
	var events: Dictionary = stats.get("events", {})
	events[event] = int(events.get(event, 0)) + 1
	stats["events"] = events


func clear_stats() -> void:
	stats = {}
	_session_start = Time.get_unix_time_from_system()
	_write_json(STATS_PATH, stats)


func _record_crash(lock_text: String) -> void:
	var info = JSON.parse_string(lock_text)
	var started: float = float(info.get("t", 0.0)) if info is Dictionary else 0.0
	crashes.append({
		"t": started,
		"version": str(info.get("version", "?")) if info is Dictionary else "?",
		"log": _previous_log_tail(),
	})
	while crashes.size() > MAX_CRASHES:
		crashes.pop_front()
	_write_json(CRASH_PATH, crashes)


## Ekor log sesi sebelumnya. Godot memutar godot.log menjadi
## godot<tanggal>.log saat game dibuka, jadi ambil file putaran yang terakhir diubah.
func _previous_log_tail() -> String:
	var logs := _old_logs()
	if logs.is_empty():
		return "(log tidak tersedia)"
	var lines := FileAccess.get_file_as_string(LOG_DIR + "/" + logs[0]).split("\n")
	return "\n".join(lines.slice(maxi(0, lines.size() - LOG_TAIL_LINES)))


## Log sesi lama (tanpa godot.log yang sedang ditulis), terbaru lebih dulu.
func _old_logs() -> Array:
	var dir := DirAccess.open(LOG_DIR)
	if dir == null:
		return []
	var files := []
	for file in dir.get_files():
		if file.begins_with("godot") and file.ends_with(".log") and file != "godot.log":
			files.append(file)
	files.sort_custom(func(a, b):
		return FileAccess.get_modified_time(LOG_DIR + "/" + a) > FileAccess.get_modified_time(LOG_DIR + "/" + b))
	return files


func _prune_logs() -> void:
	var logs := _old_logs()
	for i in range(KEEP_LOGS, logs.size()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG_DIR + "/" + logs[i]))


func last_crash() -> Dictionary:
	return crashes[-1] if not crashes.is_empty() else {}


## Teks laporan masalah untuk disalin pemain dan dikirim ke pengembang.
func problem_report() -> String:
	var lines := [
		"Laporan masalah Top Lord Like",
		"Versi: %s · %s %s" % [_version(), OS.get_name(), OS.get_version()],
		"Perangkat: %s" % OS.get_model_name(),
		"Sesi: %d · Main: %d menit" % [int(stats.get("sessions", 0)), int(stats.get("play_seconds", 0)) / 60],
	]
	if crashes.is_empty():
		lines.append("Tidak ada crash tercatat.")
	else:
		var c: Dictionary = crashes[-1]
		lines.append("Crash terakhir: sesi mulai %s (versi %s), total %d crash tercatat" % [
			Time.get_datetime_string_from_unix_time(int(c["t"]), true), c["version"], crashes.size()])
	lines = lines.map(func(line): return tr(line))
	if not crashes.is_empty():
		lines.append("--- log ---")
		lines.append(str(crashes[-1]["log"]))
	return "\n".join(lines)


func _version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.1.0"))


func _read_json(path: String, fallback):
	if not FileAccess.file_exists(path):
		return fallback
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if typeof(data) == typeof(fallback) else fallback


func _write_json(path: String, data) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
