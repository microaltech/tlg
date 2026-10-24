#!/usr/bin/env bash
# Build APK Android dari command line.
#
#   GODOT=/path/ke/godot tools/build_android.sh          # APK debug (untuk tes di HP)
#   GODOT=/path/ke/godot tools/build_android.sh release  # APK release
#
# Path Android SDK, JDK, dan debug keystore diatur sekali di Godot:
# Editor > Editor Settings > Export > Android.
# Untuk release, isi keystore lewat environment variable (jangan di-commit):
#   GODOT_ANDROID_KEYSTORE_RELEASE_PATH, GODOT_ANDROID_KEYSTORE_RELEASE_USER,
#   GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
set -euo pipefail

cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
MODE="${1:-debug}"
mkdir -p build

"$GODOT" --headless --path . --import
"$GODOT" --headless --path . --script res://tests/run_tests.gd

if [[ "$MODE" == "release" ]]; then
	"$GODOT" --headless --path . --export-release "Android" build/top-lord-like.apk
else
	"$GODOT" --headless --path . --export-debug "Android" build/top-lord-like-debug.apk
fi
ls -lh build/*.apk
