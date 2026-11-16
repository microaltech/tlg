#!/usr/bin/env bash
# Semua aset Play Store ke build/store/: tangkapan layar ponsel & tablet dalam 3 bahasa,
# feature graphic, dan video promosi 25 detik (promo.mp4, butuh ffmpeg).
#   GODOT=/path/ke/godot tools/make_store_assets.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
RUN=(xvfb-run -a -s "-screen 0 1700x2700x24")
mkdir -p build/store
for lang in id en ms; do
	"${RUN[@]}" "$GODOT" --path . --rendering-driver opengl3 --resolution 1080x1920 --script res://tools/store_assets.gd -- "$lang"
	"${RUN[@]}" "$GODOT" --path . --rendering-driver opengl3 --resolution 1600x2560 --script res://tools/store_assets.gd -- "$lang"
done
for lang in id en; do
	"${RUN[@]}" "$GODOT" --path . --rendering-driver opengl3 --resolution 1080x1920 --fixed-fps 30 \
		--write-movie build/store/promo.avi res://tools/promo_video.tscn -- "$lang"
	ffmpeg -y -loglevel error -i build/store/promo.avi -c:v libx264 -pix_fmt yuv420p -crf 23 -movflags +faststart \
		"build/store/promo_$lang.mp4"
	rm -f build/store/promo.avi build/store/promo.wav
done
ls -lh build/store
