AudioScrap — Windows port scaffold

This folder contains an initial scaffold to run AudioScrap on Windows using Swift and SwiftWin32.

What this is
- A Swift Package (targets Windows) that uses SwiftWin32 to provide SwiftUI-like APIs on Windows.
- Ported core model and manager files (`DownloadItem`, `DownloadManager`, simplified `ContentView`).
 - Ported core model and manager files (`DownloadItem`, `DownloadManager`, simplified `ContentView`).
 - Implemented Windows helpers: detection for `yt-dlp`, `ffmpeg`, and `deno`; PowerShell-based clipboard, toast notifications (PowerShell fallback), folder picker, and Explorer integration.

Build requirements (Windows)
- Install Swift for Windows: https://www.swift.org/download/#releases
- Install the Swift toolchain and ensure `swift` is on PATH.
- This scaffold depends on SwiftWin32. The package manifest references the upstream `swift-win32` package.
 
 Runtime dependencies (Windows)
- Install `yt-dlp.exe`, `ffmpeg.exe`, and `deno.exe` — prefer Windows package managers like `winget` or `chocolatey`.
- Example `winget` commands:

```powershell
winget install yt-dlp.yt-dlp
winget install Gyan.FFmpeg
winget install denoland.deno
```

Note: the exact `winget` ids may differ; `winget search yt-dlp` / `winget search ffmpeg` can help. The app detects `yt-dlp.exe`, `ffmpeg.exe`, and `deno.exe` on PATH using `where.exe`.

Native notifications helper
- A small native notifier has been added under `tools/NotifyToast`. It is a lightweight .NET WinForms program that shows a system balloon/notification.
- To build it (requires .NET 6+ SDK) run:

```powershell
cd tools\NotifyToast
dotnet publish -c Release -r win-x64 --self-contained false -o publish
# The notifier executable will be at tools\NotifyToast\publish\NotifyToast.exe
```

The app will prefer a bundled `NotifyToast.exe` (in `tools/NotifyToast` publish output) for native notifications; if not found it falls back to PowerShell methods.

The notifier also plays a short system sound when showing the notification (using `SystemSounds.Asterisk`).

Artwork embedding
- After download the app will try to locate an image file next to the downloaded audio (same base filename with .jpg/.png) and, if `ffmpeg` is available, embed it into MP3/FLAC files. This uses a best-effort `ffmpeg` call and replaces the original file on success.

Icons and styles
- The UI maps a subset of macOS SF-symbols to simple emoji and Windows-friendly visuals to give a consistent look across platforms. You can replace emoji with icons or images in `ContentView.swift`.

Build & run (from PowerShell in this folder)

```powershell
cd audioscrap-windows
swift build -c release
# executable will be in .build\release\AudioScrapWindows.exe
.build\release\AudioScrapWindows.exe
```

Notes & next steps
- This is an initial port scaffold. Many macOS APIs used by the original app were macOS-only (`AppKit`, `AVFoundation`, `UserNotifications`, `NSPasteboard`, `NSWorkspace`, `NSSound`).
- The `DownloadManager` here is simplified to demonstrate invoking `yt-dlp.exe` on Windows (via `where.exe`) and streaming its output.
- To complete the port:
  - Improve WinRT-native toast notifications (current implementation uses PowerShell fallbacks).
  - Enhance metadata/album-art extraction and embed handling (we added `ffprobe` usage but embedding artwork support can be improved).
  - Map system icons and styles to Windows visuals using SwiftWin32 views and assets for closer parity.

If you want, I can:
- Finish WinRT-native toast notifications and system integration.
- Add packaging scripts and a Windows installer that bundles required runtimes (yt-dlp, ffmpeg, deno).
- Run a build and produce a runnable `.exe` (requires Swift toolchain on Windows).
