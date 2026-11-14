extends Node
## Autoload "Notifier": menjadwalkan notifikasi lokal Android saat game
## ditinggalkan dan membatalkannya saat pemain kembali.
##
## Godot 4.3 tidak punya notifikasi lokal bawaan, jadi ini memakai singleton
## plugin Android "TlgNotify" (sumber di plugins/tlg_notify_android, addon ekspor di
## addons/tlg_notify). Tanpa plugin (PC, editor, build tanpa plugin) semua
## panggilan aman dan tidak melakukan apa-apa.

const SINGLETON := "TlgNotify"
const PERMISSION := "android.permission.POST_NOTIFICATIONS"

var _plugin: Object
var _enabled := true


func _ready() -> void:
	if Engine.has_singleton(SINGLETON):
		_plugin = Engine.get_singleton(SINGLETON)
	_enabled = Settings.notifications
	Settings.changed.connect(_on_settings_changed)
	cancel_all()  # game dibuka: notifikasi lama tidak relevan lagi
	_request_permission()


func available() -> bool:
	return _plugin != null


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST]:
		schedule_plan()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		cancel_all()


func schedule_plan() -> void:
	if available() and _plugin.has_method("update_widget"):
		var w: Array = Game.model.widget_lines(Game.now())
		_plugin.update_widget(tr_lines(w[0]), tr_lines(w[1]), tr_lines(w[2]), tr_lines(w[3]))
	if not available() or not Settings.notifications:
		return
	Game.model.active_hour = Telemetry.active_hour()
	for n in Game.model.notification_plan(Game.now()):
		_plugin.schedule(int(n["id"]), tr(str(n["title"])), tr(str(n["text"])), int(n["delay"]))
	_watch_server()


## Notifikasi dari server tanpa Firebase: selama game ditutup, plugin memeriksa
## GET /v1/notices tiap WATCH_MINUTES dan memberi tahu bila ada surat atau dagangan laku.
const WATCH_MINUTES := 240


func _watch_server() -> void:
	if not _plugin.has_method("start_server_watch"):
		return
	if Online.is_online() and Settings.notifications:
		_plugin.start_server_watch(Online.base_url(), Online.token(), WATCH_MINUTES, tr("Surat baru dari istana"),
			tr("Dagangan Tuan laku!"), tr("Buka game untuk mengambil hadiahnya."))
	else:
		_plugin.stop_server_watch()


func cancel_all() -> void:
	if available():
		_plugin.cancel_all()


func _on_settings_changed() -> void:
	if Settings.notifications == _enabled:
		return  # pengaturan lain yang berubah
	_enabled = Settings.notifications
	if _enabled:
		_request_permission()
	else:
		cancel_all()
		if available() and _plugin.has_method("stop_server_watch"):
			_plugin.stop_server_watch()


## Android 13+ butuh izin runtime untuk menampilkan notifikasi. Sistem sendiri
## berhenti menampilkan dialog setelah pemain menolak dua kali.
func _request_permission() -> void:
	if available() and Settings.notifications and OS.get_name() == "Android" \
			and not PERMISSION in OS.get_granted_permissions():
		OS.request_permission(PERMISSION)



func tr_lines(text: String) -> String:
	return tr(text)
