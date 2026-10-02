#!/usr/bin/env bash
# Builds mero-coding-class-courses.mp4 (1920x1080, 30 fps, ~30 s) from scene.html + music.py
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build
python3 music.py                                   # needs: pip install numpy
NODE_PATH="$(npm root -g)" node render.js 30       # needs: playwright + chromium
ffmpeg -y -i build/video_silent.mp4 -i build/music.wav -c:v copy -c:a aac -b:a 192k \
  -shortest -movflags +faststart mero-coding-class-courses.mp4
