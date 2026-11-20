#!/usr/bin/env bash
# Builds YT Grab.app into ~/Applications and links the ytgrab command into ~/.local/bin.
set -euo pipefail
cd "$(dirname "$0")"

fail() { echo "install: $*" >&2; exit 1; }

[[ "$(uname)" == "Darwin" ]] || fail "YT Grab is macOS only."

macos_major="$(sw_vers -productVersion | cut -d. -f1)"
(( macos_major >= 14 )) || fail "needs macOS 14 (Sonoma) or newer; you have $(sw_vers -productVersion)."

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

command -v brew >/dev/null || fail "Homebrew is required. Install it from https://brew.sh, then rerun ./install.sh"

if ! command -v swiftc >/dev/null || ! xcrun --find swiftc >/dev/null 2>&1; then
  echo "install: the Swift compiler is missing. Opening the Command Line Tools installer..." >&2
  xcode-select --install 2>/dev/null || true
  fail "finish the Command Line Tools install, then rerun ./install.sh"
fi

for dep in yt-dlp ffmpeg deno; do
  command -v "$dep" >/dev/null || brew install "$dep"
done

case "$(uname -m)" in
  arm64) arch="arm64" ;;
  x86_64) arch="x86_64" ;;
  *) fail "unsupported CPU: $(uname -m)" ;;
esac

app="build/YT Grab.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"

echo "Building YT Grab.app..."
swiftc -O -parse-as-library -target "${arch}-apple-macos14" \
  app/YTGrab.swift -o "$app/Contents/MacOS/YTGrab"
cp app/Info.plist "$app/Contents/Info.plist"
cp bin/ytgrab "$app/Contents/Resources/ytgrab"
chmod +x "$app/Contents/Resources/ytgrab" bin/ytgrab
codesign --force --deep --sign - "$app" 2>/dev/null

pkill -x YTGrab 2>/dev/null || true
for _ in {1..20}; do pgrep -x YTGrab >/dev/null || break; sleep 0.25; done
mkdir -p "$HOME/Applications" "$HOME/.local/bin"
rm -rf "$HOME/Applications/YT Grab.app"
cp -R "$app" "$HOME/Applications/"
ln -sf "$PWD/bin/ytgrab" "$HOME/.local/bin/ytgrab"

echo "Installed ~/Applications/YT Grab.app and ~/.local/bin/ytgrab"

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) echo "Note: add ~/.local/bin to your PATH to use ytgrab, e.g.  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc" ;;
esac

# LaunchServices can briefly refuse to relaunch an app that was just killed, so retry
for _ in {1..10}; do
  open "$HOME/Applications/YT Grab.app" 2>/dev/null && break
  sleep 0.5
done
if pgrep -x YTGrab >/dev/null || { sleep 1; pgrep -x YTGrab >/dev/null; }; then
  echo "YT Grab is running. Look for the ↓ icon in your menu bar."
else
  echo "Built OK, but it didn't launch. Open YT Grab from ~/Applications or Spotlight."
fi
