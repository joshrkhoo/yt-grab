# YT Grab

Paste YouTube (or TikTok, Vimeo, SoundCloud, etc.) links and get MP4/MP3 files saved to `~/Downloads`. Everything runs locally on your Mac. There is no server, website or account.

It is a thin wrapper around [yt-dlp](https://github.com/yt-dlp/yt-dlp) and ffmpeg, in two forms:

- **Menu-bar app** (`YT Grab.app`): click the ↓ icon, paste links, pick MP4/MP3 and quality, then Download (or ⌘↩).
- **Terminal command** (`ytgrab`): the same thing from the shell or from Vim.

## Install

```sh
./install.sh
```

This installs yt-dlp, ffmpeg and deno via Homebrew if they're missing, builds `~/Applications/YT Grab.app`, and links `ytgrab` into `~/.local/bin`.

To launch the app at login: System Settings → General → Login Items → add **YT Grab**.

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

From Vim, put the cursor on a link and run `:!ytgrab <cWORD>`, or download every link in the buffer with `:w !ytgrab`.

## Notes

- MP4s prefer H.264 + AAC, so they open in QuickTime, Photos and iMovie. YouTube only serves H.264 up to 1080p, so above that you may get VP9/AV1.
- If downloads start failing, YouTube has probably changed something. Run `ytgrab -U`.
- For personal use. Downloading may break the source site's terms of service.
