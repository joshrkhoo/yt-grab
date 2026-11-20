#!/usr/bin/env bash
# Builds YT Grab.app into ~/Applications and links the ytgrab command into ~/.local/bin.
set -euo pipefail
cd "$(dirname "$0")"

export PATH="/opt/homebrew/bin:$PATH"
for dep in yt-dlp ffmpeg deno; do
  command -v "$dep" >/dev/null || brew install "$dep"
done

app="build/YT Grab.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"

swiftc -O -parse-as-library -target arm64-apple-macos14 \
  app/YTGrab.swift -o "$app/Contents/MacOS/YTGrab"
cp app/Info.plist "$app/Contents/Info.plist"
cp bin/ytgrab "$app/Contents/Resources/ytgrab"
chmod +x "$app/Contents/Resources/ytgrab"
codesign --force --deep --sign - "$app"

mkdir -p "$HOME/Applications" "$HOME/.local/bin"
rm -rf "$HOME/Applications/YT Grab.app"
cp -R "$app" "$HOME/Applications/"
ln -sf "$PWD/bin/ytgrab" "$HOME/.local/bin/ytgrab"

echo "Installed ~/Applications/YT Grab.app and ~/.local/bin/ytgrab"
