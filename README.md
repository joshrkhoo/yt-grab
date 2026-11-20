# YT Grab

Paste YouTube (or TikTok, Vimeo, SoundCloud, etc.) links and get MP4/MP3 files saved to `~/Downloads`. Everything runs locally on your Mac. There is no server, website or account.

It is a thin wrapper around [yt-dlp](https://github.com/yt-dlp/yt-dlp) and ffmpeg, in two forms:

- **Menu-bar app** (`YT Grab.app`): click the ↓ icon, paste links, pick MP4/MP3 and quality, then Download (or ⌘↩).
- **Terminal command** (`ytgrab`): the same thing from the shell or from Vim.

## Requirements

- macOS 14 (Sonoma) or newer, on Apple Silicon or Intel
- [Homebrew](https://brew.sh)
- Xcode Command Line Tools, for the Swift compiler. The installer prompts you if they're missing; you can also run `xcode-select --install`.

## Install

```sh
git clone https://github.com/joshrkhoo/yt-grab.git
cd yt-grab
./install.sh
```

The installer:

1. installs `yt-dlp`, `ffmpeg` and `deno` via Homebrew if they're missing (yt-dlp needs deno for YouTube),
2. builds the app from source into `~/Applications/YT Grab.app`,
3. links the `ytgrab` command into `~/.local/bin`,
4. launches the app. Look for the ↓ icon in your menu bar.

To launch the app at login: System Settings → General → Login Items → add **YT Grab**.

To update to the latest version, run `git pull && ./install.sh`. To remove it, run `./uninstall.sh`.

## Menu-bar app

1. Click the ↓ icon in the menu bar.
2. Paste one or more links (one per line), or click **Paste**.
3. Choose **MP4** or **MP3**, and a quality or bitrate.
4. Click **Download** or press ⌘↩.

Each link shows its title and progress. ✕ cancels it, and the magnifying glass shows the finished file in Finder. Downloads keep running after you close the panel. The icon fills in while any are running, and a sound plays when each one finishes.

Can't see the icon? On MacBooks with a notch, a crowded menu bar can hide it. Quit a few other menu-bar apps, or check System Settings → Menu Bar.

## Terminal usage

```sh
ytgrab https://youtu.be/dQw4w9WgXcQ             # MP4, up to 1080p
ytgrab -a https://youtu.be/dQw4w9WgXcQ          # MP3, 320 kb/s
ytgrab -q 720 url1 url2 url3                     # several at once
ytgrab                                           # paste links, blank line to start
ytgrab -a -o ~/Music/inbox url                   # custom folder
ytgrab -U                                        # update yt-dlp
```

| Option | Meaning |
| --- | --- |
| `-a`, `--audio` | MP3 instead of MP4 |
| `-q N` | max video height (default 1080) |
| `-b N` | MP3 bitrate (default 320) |
| `-o DIR` | save folder (default `~/Downloads`, or `$YTGRAB_DIR`) |
| `-p` | download the whole playlist |
| `-U` | update yt-dlp |

In zsh, put quotes around links that contain `?` (`ytgrab 'https://youtube.com/watch?v=...'`), or zsh will treat them as file patterns. Running `ytgrab` with no arguments and pasting avoids this.

From Vim, put the cursor on a link and run:

```vim
:exe '!ytgrab' shellescape(expand('<cWORD>'), 1)
```

To download every link in a buffer (one per line), run `:w !ytgrab`. Add `-a` after `ytgrab` in either command for MP3.

## Notes

- MP4s prefer H.264 + AAC, so they open in QuickTime, Photos and iMovie. YouTube only serves H.264 up to 1080p, so above that you may get VP9/AV1.
- If downloads start failing, YouTube has probably changed something. Run `ytgrab -U`.
- For personal use. Downloading may break the source site's terms of service.

## How it works

`bin/ytgrab` is a Bash wrapper that turns your options into yt-dlp flags (format sorting for H.264 MP4, or extraction to MP3 with embedded cover art). The menu-bar app (`app/YTGrab.swift`, SwiftUI) bundles that same script. It runs the script once per link with `YTGRAB_MACHINE=1`, which switches the output to simple `TITLE` / `PCT` / `FILE` lines that the app parses to show progress.

## License

[MIT](LICENSE)
