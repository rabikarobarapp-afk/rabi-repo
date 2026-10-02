#!/usr/bin/env bash
# Builds both 1920x1080, 30 fps, 30 s videos:
#   mero-coding-class-bright.mp4   (brand colors, scene-bright.html)
#   mero-coding-class-courses.mp4  (dark neon, scene.html)
# Needs: python3 + numpy, node + playwright (chromium), ffmpeg
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build
python3 music.py
export NODE_PATH="$(npm root -g)"
SCENE=scene-bright.html OUT=build/bright_silent.mp4 node render.js 30
SCENE=scene.html OUT=build/video_silent.mp4 node render.js 30
for pair in "bright_silent:mero-coding-class-bright" "video_silent:mero-coding-class-courses"; do
  ffmpeg -y -i "build/${pair%%:*}.mp4" -i build/music.wav -c:v copy -c:a aac -b:a 192k \
    -shortest -movflags +faststart "${pair##*:}.mp4"
done
