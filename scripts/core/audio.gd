extends Node
## Autoload "Audio": musik latar (crossfade saat pindah halaman) dan efek suara.
## Pengaturan nyala/mati disimpan di user://settings.cfg.

const SETTINGS_PATH := "user://settings.cfg"
const MUSIC_DB := -6.0
const SFX_VOICES := 8

var music_on := true
var sfx_on := true
var _music: Array[AudioStreamPlayer] = []
var _active := 0
var _track := ""
var _music_tween: Tween
var _sfx: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _streams := {}


func _ready() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -80.0
		add_child(p)
		_music.append(p)
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx.append(p)
	_load_settings()


func _ensure_bus(bus: String) -> void:
	if AudioServer.get_bus_index(bus) != -1:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, bus)
	AudioServer.set_bus_send(i, "Master")


func _stream(file: String, loop := false) -> AudioStream:
	if not _streams.has(file):
		var path := "res://assets/audio/%s.ogg" % file
		var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
		if s is AudioStreamOggVorbis:
			s.loop = loop
		_streams[file] = s
	return _streams[file]


## Ganti musik latar dengan crossfade. track: "city", "battle", "palace".
func play_music(track: String) -> void:
	if track == _track:
		return
	_track = track
	var old := _music[_active]
	_active = 1 - _active
	var new := _music[_active]
	new.stream = _stream("music_" + track, true)
	if new.stream == null:
		return
	new.volume_db = -40.0
	new.play()
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween().set_parallel()
	_music_tween.tween_property(new, "volume_db", MUSIC_DB, 1.2)
	_music_tween.tween_property(old, "volume_db", -60.0, 1.0)
	_music_tween.chain().tween_callback(old.stop)


## Mainkan efek suara; pitch sedikit diacak supaya tidak monoton.
func play(sound: String, pitch_jitter := 0.04) -> void:
	if not sfx_on or sound == "":
		return
	var s := _stream("sfx_" + sound)
	if s == null:
		return
	var p := _sfx[_next_voice]
	_next_voice = (_next_voice + 1) % SFX_VOICES
	p.stream = s
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


func set_music_on(on: bool) -> void:
	music_on = on
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not on)
	_save_settings()


func set_sfx_on(on: bool) -> void:
	sfx_on = on
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), not on)
	_save_settings()


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		music_on = cfg.get_value("audio", "music", true)
		sfx_on = cfg.get_value("audio", "sfx", true)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not music_on)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), not sfx_on)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_on)
	cfg.set_value("audio", "sfx", sfx_on)
	cfg.save(SETTINGS_PATH)
