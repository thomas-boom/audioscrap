**AudioScrap**

<img width="1012" height="762" alt="Scherm­afbeelding 2025-12-08 om 1 42 19 PM" src="https://github.com/user-attachments/assets/a310cf35-008c-40c0-a7eb-7d91d0bf952a" />


- **Purpose**: A small macOS SwiftUI app that uses `yt-dlp` to download audio from YouTube and SoundCloud, convert to MP3 (with metadata and embedded thumbnail), and save to a user-selected folder.

**Requirements**
- **macOS**: Built with Swift/SwiftUI (Xcode required to build/run).
- **yt-dlp**: Required for downloading and audio extraction. (The app detects `yt-dlp` and provides remediation actions.)
- **Deno**: `yt-dlp` requires the Deno JS runtime for some operations; install if the app indicates it's missing.
- **ffmpeg**: Required for audio conversion and embedding thumbnails/metadata. `yt-dlp` must be able to find `ffmpeg`.
- **Homebrew (recommended)**: Simplifies installing `yt-dlp`, `deno` and `ffmpeg`.

**Quick Install (user)**
- Install Homebrew (if you don't have it):

```zsh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

- Install required tools via Homebrew (recommended):

```zsh
brew install yt-dlp deno ffmpeg
```

- Run the app:
  - Open `audioscrap.xcodeproj` or `audioscrap.xcworkspace` in Xcode and run the scheme `audioscrap`.
  - Alternatively, build and run as you would any macOS app from Xcode.

**Developer / Build Instructions**
- Open the workspace in Xcode:

```zsh
open audioscrap.xcodeproj
```

- Select the `audioscrap` target and run in the macOS simulator or on your Mac.
- The app uses `Process` to invoke external binaries (`yt-dlp`, `deno`, `ffmpeg`). Ensure the build configuration/environment allows launching these tools (during development, App Sandbox may need adjusting).

**App Usage**
- Paste a YouTube or SoundCloud URL into the URL field and press `Download`.
- Choose a save location via the `Change...` button.
- The app converts audio to MP3 and attempts to embed thumbnail and metadata.
- The app converts audio to MP3 by default and attempts to embed thumbnail and metadata. FLAC (lossless) export is also available from the `Settings`.
- Audio quality: a picker is available (e.g. `0` = best variable, or specific bitrates like `320k`). Note: bitrate/quality options apply to MP3 only; when `FLAC` is selected the app disables the bitrate picker and uses a lossless export (default `best`).
- The app shows runtime readiness indicators (yt-dlp, deno, ffmpeg) in the bottom status bar. If any are missing, open `Settings` (gear) to recheck or run remediation actions.

**Persistence & Settings**
- `audioFormat` and `audioQuality` are persisted to `UserDefaults`.
- `saveLocation` is now persisted to `UserDefaults` (the app will only adopt a saved location if the folder exists).

**FLAC Export**
- FLAC is offered as a lossless export option in `Settings` alongside `MP3`.
- When FLAC is selected:
  - The audio is exported losslessly; bitrate/quality pickers are disabled because they do not apply to FLAC.
  - The app defaults to the best/lossless setting (`0`) for compatibility and fidelity.
  - `ffmpeg` support is recommended to ensure proper container tagging and post-processing; install via Homebrew if you need authoritative tag handling:

```bash
brew install ffmpeg
```

Notes:
- FLAC files are larger than MP3 but preserve full audio fidelity.
- The app reads final tags from the saved FLAC file after download completes (prefers `ffprobe` when available, falls back to AVFoundation metadata reading).

**Permissions & Notes**
- Notifications: the app requests permission to post notifications (used for missing-tool alerts and status updates).
- Terminal automation: some remediation flows (opening Terminal and running `chmod`) use `osascript` and may require Automation permissions or a non-sandboxed build.
- App Sandbox: many of the remediation helpers (running `chmod`, launching Terminal) rely on being allowed to run system commands; for distribution you may need a privileged helper or alternative workflows.

**Troubleshooting**
- If downloads fail or `yt-dlp` can't find `ffmpeg`/`deno`:
  - Confirm binaries are installed and executable: `which yt-dlp deno ffmpeg` and `ls -l $(which yt-dlp)`.
  - The app will try to prepend detected `ffmpeg` / `deno` directories to the launched process `PATH`, but if binaries are installed in non-standard locations adjust your environment or install via Homebrew.
- If the saved folder no longer exists, the app falls back to your `Downloads` folder and logs a debug message.

**Files of interest**
- `ContentView.swift` — Main UI and About/Settings views.
- `DownloadManager.swift` — Orchestrates detection, remediation, and runs `yt-dlp` processes.
- `DownloadItem.swift` — Model for downloads and progress.

**Contributing & Issues**
- Repo: https://github.com/thomas-boom/audioscrap
- File issues or contribute via GitHub pull requests.

**License**
- No license file included in the repository. Add a `LICENSE` if you want to specify one.
