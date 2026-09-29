#!/usr/bin/env bash
set -euo pipefail

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is not installed. Install it from https://brew.sh first." >&2
  exit 1
fi

brew update
brew install ffmpeg

ffmpeg -version
