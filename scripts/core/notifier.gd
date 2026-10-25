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
	if not available() or not Settings.notifications:
		return
	for n in Game.model.notification_plan(Game.now()):
		_plugin.schedule(int(n["id"]), str(n["title"]), str(n["text"]), int(n["delay"]))


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


## Android 13+ butuh izin runtime untuk menampilkan notifikasi. Sistem sendiri
## berhenti menampilkan dialog setelah pemain menolak dua kali.
func _request_permission() -> void:
	if available() and Settings.notifications and OS.get_name() == "Android" \
			and not PERMISSION in OS.get_granted_permissions():
		OS.request_permission(PERMISSION)
