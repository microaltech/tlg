extends Node
## Autoload "Ads": iklan video berhadiah.
##
## - AdMob: aktif bila build Android menyertakan plugin dengan singleton "AdMob"
##   (antarmuka: initialize(), load_rewarded(unit_id), show_rewarded(); sinyal
##   rewarded_ad_loaded, rewarded_ad_failed_to_load(code), user_earned_reward,
##   rewarded_ad_closed). BELUM diuji di perangkat; sesuaikan nama metode/sinyal
##   dengan versi plugin yang dipakai, lalu uji di jalur pengujian internal.
## - Mode Uji (hanya build debug): iklan disimulasikan beberapa detik.
## - Build rilis tanpa plugin: iklan tidak tersedia, tombolnya disembunyikan.
##
## Hadiah selalu diberikan lewat GameModel.grant_ad_reward (menghormati batas harian).

signal ad_finished(result: Dictionary)
signal ad_started(kind: String)

## ID unit iklan berhadiah. Ganti dengan ID dari konsol AdMob sebelum rilis;
## ini ID uji resmi Google yang selalu menampilkan iklan percobaan.
const REWARDED_UNIT_ID := "ca-app-pub-3940256099942544/5224354917"
const TEST_AD_SECONDS := 2.0

enum Mode { ADMOB, TEST, UNAVAILABLE }

var mode := Mode.UNAVAILABLE
var loaded := false
var _admob: Object = null
var _pending := ""  ## jenis hadiah yang sedang menunggu iklan selesai
var _earned := false


func _ready() -> void:
	if Engine.has_singleton("AdMob"):
		_admob = Engine.get_singleton("AdMob")
		mode = Mode.ADMOB
		for pair in [["rewarded_ad_loaded", func(): loaded = true],
				["rewarded_ad_failed_to_load", func(_code): loaded = false],
				["user_earned_reward", func(_a = null, _b = null): _earned = true],
				["rewarded_ad_closed", _on_closed]]:
			if _admob.has_signal(pair[0]):
				_admob.connect(pair[0], pair[1])
			else:
				push_warning("Plugin AdMob tidak punya sinyal '%s'; periksa versi plugin." % pair[0])
		_admob.initialize()
		_admob.load_rewarded(REWARDED_UNIT_ID)
	elif OS.is_debug_build():
		mode = Mode.TEST


func available() -> bool:
	return mode == Mode.TEST or (mode == Mode.ADMOB and loaded)


func busy() -> bool:
	return _pending != ""


## Tonton iklan untuk hadiah `kind` (lihat Data.AD_REWARDS).
func show_rewarded(kind: String) -> void:
	if busy():
		return
	if Game.model.ad_left(kind, Game.now()) <= 0:
		ad_finished.emit({"ok": false, "msg": "Batas iklan hadiah hari ini sudah habis."})
		return
	if not available():
		ad_finished.emit({"ok": false, "msg": "Iklan belum tersedia. Coba lagi sebentar."})
		return
	_pending = kind
	_earned = false
	ad_started.emit(kind)
	if mode == Mode.TEST:
		get_tree().create_timer(TEST_AD_SECONDS).timeout.connect(func():
			_earned = true
			_on_closed())
	else:
		loaded = false
		_admob.show_rewarded()


func _on_closed() -> void:
	var kind := _pending
	_pending = ""
	if mode == Mode.ADMOB:
		_admob.load_rewarded(REWARDED_UNIT_ID)  # siapkan iklan berikutnya
	if not _earned:
		ad_finished.emit({"ok": false, "msg": "Iklan ditutup sebelum selesai, hadiah tidak diberikan."})
		return
	ad_finished.emit(Game.model.grant_ad_reward(kind, Game.now()))
