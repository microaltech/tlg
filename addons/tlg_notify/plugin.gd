@tool
extends EditorPlugin
## Menyertakan AAR plugin TlgNotify saat ekspor Android (butuh Gradle build).
## AAR dibangun dari plugins/tlg_notify_android; tanpa AAR ekspor tetap jalan tanpa notifikasi.

var _export: AndroidExport


func _enter_tree() -> void:
	_export = AndroidExport.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null


class AndroidExport extends EditorExportPlugin:
	const AAR := "tlg_notify/bin/tlg_notify-release.aar"

	# Godot mewajibkan Gradle build begitu ada plugin Android aktif, jadi plugin
	# ini hanya aktif bila AAR-nya sudah dibangun.
	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid and FileAccess.file_exists("res://addons/" + AAR)

	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray([AAR])

	func _get_name() -> String:
		return "TlgNotify"
