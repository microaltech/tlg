#!/usr/bin/env bash
# Build APK Android dari command line.
#
#   GODOT=/path/ke/godot tools/build_android.sh          # APK debug (untuk tes di HP)
#   GODOT=/path/ke/godot tools/build_android.sh release  # APK release
#   GODOT=/path/ke/godot tools/build_android.sh aab      # AAB untuk Google Play (butuh Gradle build)
#
# Path Android SDK, JDK, dan debug keystore diatur sekali di Godot:
# Editor > Editor Settings > Export > Android.
# Untuk release/aab, buat keystore sekali dengan tools/make_keystore.sh, lalu isi
# lewat environment variable (jangan di-commit):
#   GODOT_ANDROID_KEYSTORE_RELEASE_PATH, GODOT_ANDROID_KEYSTORE_RELEASE_USER,
#   GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
set -euo pipefail

cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
MODE="${1:-debug}"
mkdir -p build

"$GODOT" --headless --path . --import
# Error skrip di tengah tes menghentikan tes itu tanpa dihitung gagal, jadi periksa juga lognya.
TEST_LOG="$(mktemp)"
"$GODOT" --headless --path . --script res://tests/run_tests.gd 2>&1 | tee "$TEST_LOG"
if [[ "${PIPESTATUS[0]}" -ne 0 ]] || grep -q "SCRIPT ERROR" "$TEST_LOG"; then
	echo "Tes gagal, build dibatalkan." >&2
	rm -f "$TEST_LOG"
	exit 1
fi
rm -f "$TEST_LOG"

if [[ "$MODE" == "aab" ]]; then
	# Preset AAB memakai Gradle build: jalankan Project > Install Android Build
	# Template sekali di editor sebelum perintah ini.
	"$GODOT" --headless --path . --export-release "Android AAB (Play Store)" build/top-lord-like.aab
	ls -lh build/*.aab
	exit 0
elif [[ "$MODE" == "release" ]]; then
	"$GODOT" --headless --path . --export-release "Android" build/top-lord-like.apk
else
	"$GODOT" --headless --path . --export-debug "Android" build/top-lord-like-debug.apk
fi
ls -lh build/*.apk
