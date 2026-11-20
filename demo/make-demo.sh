#!/usr/bin/env bash
# Regenerates docs/demo.gif from the real SwiftUI panel. Needs swiftc and ffmpeg.
set -euo pipefail
cd "$(dirname "$0")/.."

work="build/demo"
rm -rf "$work"
mkdir -p "$work/frames" docs

swiftc -O -D DEMO app/YTGrab.swift demo/main.swift -o "$work/recorder"
"$work/recorder" "$work/frames"

# Two-pass palette keeps the GIF small and the UI colours accurate
ffmpeg -loglevel error -y -framerate 15 -i "$work/frames/f%04d.png" \
  -vf "scale=900:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" \
  -loop 0 docs/demo.gif

echo "Wrote docs/demo.gif ($(du -h docs/demo.gif | cut -f1))"
