extends Node
## Autoload "Settings": preferensi perangkat (bukan progres game), disimpan di
## user://settings.cfg. Progres game (termasuk nama Tuan) tetap di save.json.

signal changed

const PATH := "user://settings.cfg"
const DEFAULT_VOLUME := 80

var music_volume := DEFAULT_VOLUME  ## 0–100; 0 = mati
var sfx_volume := DEFAULT_VOLUME  ## 0–100; 0 = mati
var battery_saver := false  ## 30 FPS + mode prosesor rendah
var notifications := true  ## pengingat lokal Android (charge penuh, rekrut gratis)
var language := "auto"  ## "auto" (ikuti bahasa perangkat), "id", atau "en"
var analytics := true  ## statistik bermain lokal (tidak dikirim ke mana pun)
var battle_speed := 1  ## kecepatan tayangan perang: 1 atau 2
var skip_battles := false  ## lewati tayangan perang, langsung tampilkan hasil
var server_url := ""  ## alamat server sosial (kosong = mode offline)
## Kalender login versi teks; dinyalakan otomatis bila kalender bergambar
## pernah membuat game crash di perangkat ini.
var simple_login := false


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		# Versi lama menyimpan musik/suara sebagai nyala/mati saja.
		var old_music: bool = cfg.get_value("audio", "music", true)
		var old_sfx: bool = cfg.get_value("audio", "sfx", true)
		music_volume = clampi(int(cfg.get_value("audio", "music_volume", DEFAULT_VOLUME if old_music else 0)), 0, 100)
		sfx_volume = clampi(int(cfg.get_value("audio", "sfx_volume", DEFAULT_VOLUME if old_sfx else 0)), 0, 100)
		battery_saver = bool(cfg.get_value("device", "battery_saver", false))
		notifications = bool(cfg.get_value("device", "notifications", true))
		analytics = bool(cfg.get_value("privacy", "analytics", true))
		language = str(cfg.get_value("device", "language", "auto"))
		battle_speed = 2 if int(cfg.get_value("battle", "speed", 1)) == 2 else 1
		skip_battles = bool(cfg.get_value("battle", "skip", false))
		server_url = str(cfg.get_value("online", "url", ""))
		simple_login = bool(cfg.get_value("device", "simple_login_v2", false))
	_apply_power()


func set_value(key: String, value) -> void:
	set(key, value)
	if key == "battery_saver":
		_apply_power()
	save()
	changed.emit()


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("device", "battery_saver", battery_saver)
	cfg.set_value("device", "notifications", notifications)
	cfg.set_value("privacy", "analytics", analytics)
	cfg.set_value("device", "language", language)
	cfg.set_value("battle", "speed", battle_speed)
	cfg.set_value("battle", "skip", skip_battles)
	cfg.set_value("online", "url", server_url)
	cfg.set_value("device", "simple_login_v2", simple_login)
	cfg.save(PATH)


func _apply_power() -> void:
	Engine.max_fps = 30 if battery_saver else 60
	OS.low_processor_usage_mode = battery_saver
