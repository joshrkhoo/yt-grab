#!/usr/bin/env bash
# Removes YT Grab.app and the ytgrab link. Leaves yt-dlp/ffmpeg/deno and your downloads alone.
set -euo pipefail

pkill -x YTGrab 2>/dev/null || true
rm -rf "$HOME/Applications/YT Grab.app"
[[ -L "$HOME/.local/bin/ytgrab" ]] && rm "$HOME/.local/bin/ytgrab"
defaults delete com.joshrkhoo.ytgrab 2>/dev/null || true

echo "YT Grab removed. To also remove its tools: brew uninstall yt-dlp ffmpeg deno"
