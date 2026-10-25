extends Node
## Autoload "PlayGames": Google Play Games Services (pencapaian & cadangan save cloud).
##
## Aktif bila build Android menyertakan plugin dengan singleton
## "GodotPlayGameServices" (mis. godot-play-game-services). Pemanggilan dijaga
## dengan has_method/has_signal karena nama API berbeda antarversi plugin; BELUM
## diuji di perangkat. Tanpa plugin semua fungsi aman dan tidak melakukan apa-apa.
##
## Sebelum rilis: buat pencapaian di Play Console (Play Games Services) lalu isi
## ACHIEVEMENT_IDS dengan ID-nya ("CgkI..."), satu per tingkat.

signal cloud_loaded(data: String)
signal cloud_result(ok: bool, message: String)

const SINGLETON := "GodotPlayGameServices"
const SNAPSHOT_NAME := "toplordlike_save"

## "id_pencapaian:tingkat" -> ID Play Console. Kosong = tidak dilaporkan.
const ACHIEVEMENT_IDS := {
	# "conqueror:1": "CgkIxxxxxxxxEAIQAQ",
}

var _plugin: Object


func _ready() -> void:
	if Engine.has_singleton(SINGLETON):
		_plugin = Engine.get_singleton(SINGLETON)
		_call("initialize")
		for pair in [["gameSaved", func(ok, _a = null, _b = null): cloud_result.emit(bool(ok),
					"Tersimpan ke cloud." if ok else "Gagal menyimpan ke cloud.")],
				["gameLoaded", func(data): cloud_loaded.emit(str(data))]]:
			if _plugin.has_signal(pair[0]):
				_plugin.connect(pair[0], pair[1])
	Game.model.achievement_reached.connect(_on_achievement)


func available() -> bool:
	return _plugin != null


func _call(method: String, args := []) -> void:
	if _plugin and _plugin.has_method(method):
		_plugin.callv(method, args)
	elif _plugin:
		push_warning("Plugin Play Games tidak punya metode '%s'; periksa versi plugin." % method)


func _on_achievement(id: String, tier: int) -> void:
	var play_id: String = ACHIEVEMENT_IDS.get("%s:%d" % [id, tier], "")
	if play_id != "":
		_call("unlockAchievement", [play_id])


func show_achievements() -> void:
	_call("showAchievements")


func save_cloud(data: String) -> void:
	if not available():
		cloud_result.emit(false, "Google Play Games tidak tersedia di versi ini.")
		return
	_call("saveGame", [SNAPSHOT_NAME, "Top Lord Like", data])


func load_cloud() -> void:
	if not available():
		cloud_result.emit(false, "Google Play Games tidak tersedia di versi ini.")
		return
	_call("loadGame", [SNAPSHOT_NAME, false])
