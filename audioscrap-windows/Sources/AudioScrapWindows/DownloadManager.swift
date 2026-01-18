import Foundation
import Combine

// NOTE: This is a Windows-targeted port scaffold. Many macOS-specific APIs (NSWorkspace, NSPasteboard,
// AVFoundation, UNUserNotificationCenter, shell paths like /usr/bin/which, Homebrew helpers) are
// replaced with minimal placeholders. The goal is to preserve the download orchestration and
// re-use the same backends (yt-dlp, ffmpeg, deno) on Windows by invoking their executables when available.

class DownloadManager: ObservableObject {
    @Published var downloads: [DownloadItem] = []
    @Published var isYtDlpInstalled = false
    @Published var ytDlpPath: String = ""
    @Published var saveLocation: String = ""
    @Published var isFfmpegInstalled: Bool = false
    @Published var ffmpegPath: String = ""
    @Published var isDenoInstalled: Bool = false
    @Published var denoPath: String = ""

    // Minimal audio format/quality options (kept from macOS app)
    @Published var audioFormat: String = "mp3"
    @Published var audioQuality: String = "0"

    let availableAudioFormats: [String] = ["mp3", "flac"]
    let availableAudioQualityOptions: [(label: String, value: String)] = [
        ("Best (0)", "0"),
        ("320k", "320k"),
        ("256k", "256k"),
        ("192k", "192k"),
        ("128k", "128k")
    ]

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Default to user's Downloads folder on Windows
        #if os(Windows)
        if let home = ProcessInfo.processInfo.environment["USERPROFILE"] {
            self.saveLocation = (home as NSString).appendingPathComponent("Downloads")
        } else {
            self.saveLocation = "."
        }
        #else
        self.saveLocation = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? "."
        #endif

        // Run a quick detection of required tools asynchronously
        DispatchQueue.global(qos: .background).async {
            self.detectYtDlp()
            // detect ffmpeg/deno on Windows
            self.detectFfmpeg()
            self.detectDeno()
        }
    }

    func detectYtDlp() {
        #if os(Windows)
        // On Windows `where` can be used to find executables on PATH
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "C:/Windows/System32/where.exe")
        task.arguments = ["yt-dlp.exe"]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty {
                DispatchQueue.main.async {
                    self.isYtDlpInstalled = true
                    self.ytDlpPath = path
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.isYtDlpInstalled = false
            }
        }
        #else
        // Non-Windows placeholder: keep existing macOS behavior as-is
        #endif
    }

    func detectFfmpeg() {
        #if os(Windows)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "C:/Windows/System32/where.exe")
        task.arguments = ["ffmpeg.exe"]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty {
                DispatchQueue.main.async {
                    self.isFfmpegInstalled = true
                    self.ffmpegPath = path
                }
            }
        } catch {
            DispatchQueue.main.async { self.isFfmpegInstalled = false }
        }
        #endif
    }

    func detectDeno() {
        #if os(Windows)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "C:/Windows/System32/where.exe")
        task.arguments = ["deno.exe"]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty {
                DispatchQueue.main.async {
                    self.isDenoInstalled = true
                    self.denoPath = path
                }
            }
        } catch {
            DispatchQueue.main.async { self.isDenoInstalled = false }
        }
        #endif
    }

    // MARK: - Helpers: Clipboard, Explorer, Notifications, PowerShell
    func copyToClipboard(_ text: String) {
        #if os(Windows)
        // Use PowerShell to set clipboard as a cross-tool fallback
        let script = "Set-Clipboard -Value \"\(text.replacingOccurrences(of: "\"", with: "\\\"") )\""
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe")
        task.arguments = ["-NoProfile", "-Command", script]
        do { try task.run(); task.waitUntilExit() } catch { }
        #else
        // macOS fallback: use NSPasteboard
        #endif
    }

    func openInExplorer(path: String) {
        #if os(Windows)
        let normalized = path.replacingOccurrences(of: "/", with: "\\")
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "C:/Windows/System32/explorer.exe")
        task.arguments = ["/select,\(normalized)"]
        do { try task.run() } catch { }
        #else
        // macOS fallback
        #endif
    }

    func notify(title: String, body: String) {
        #if os(Windows)
        // Prefer a bundled native notifier if present (tools/NotifyToast)
        let candidates = [
            "./tools/NotifyToast/bin/Release/net6.0-windows/NotifyToast.exe",
            "./tools/NotifyToast/bin/Debug/net6.0-windows/NotifyToast.exe",
            "./tools/NotifyToast/NotifyToast.exe"
        ]
        for c in candidates {
            if FileManager.default.fileExists(atPath: c) {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: c)
                task.arguments = [title, body]
                do { try task.run(); return } catch { }
            }
        }

        // Fallback to PowerShell-based toast (best-effort) then message fallback
        let toastScript = "[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null; $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02); $txt = $template.GetElementsByTagName('text'); $txt.Item(0).AppendChild($template.CreateTextNode('\"\(title.replacingOccurrences(of: "'", with: "\'"))\"')) | Out-Null; $txt.Item(1).AppendChild($template.CreateTextNode('\"\(body.replacingOccurrences(of: "'", with: "\'"))\"')) | Out-Null; $xml = New-Object Windows.Data.Xml.Dom.XmlDocument; $xml.LoadXml($template.GetXml()); $toast = New-Object Windows.UI.Notifications.ToastNotification $xml; [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('AudioScrap').Show($toast)"
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe")
        task.arguments = ["-NoProfile", "-Command", toastScript]
        do { try task.run(); task.waitUntilExit() } catch {
            // fallback to MessageBox
            let fallback = Process()
            fallback.executableURL = URL(fileURLWithPath: "C:/Windows/System32/msg.exe")
            fallback.arguments = ["%username%", "\"\(title): \(body)\""]
            try? fallback.run()
        }
        #else
        // macOS fallback: UNUserNotificationCenter
        #endif
    }

    func openPowerShellAndRun(_ command: String) {
        #if os(Windows)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe")
        task.arguments = ["-NoExit", "-Command", command]
        do { try task.run() } catch { }
        #endif
    }

    func addDownload(url: String) {
        let item = DownloadItem(url: url)
        DispatchQueue.main.async {
            self.downloads.append(item)
        }
        startDownload(item: item)
    }

    func removeDownload(item: DownloadItem) {
        downloads.removeAll { $0.id == item.id }
    }

    private func startDownload(item: DownloadItem) {
        guard isYtDlpInstalled else {
            DispatchQueue.main.async {
                item.status = .failed
                item.error = "yt-dlp is not installed on PATH."
            }
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            self.performDownload(item: item)
        }
    }

    // After download completes, try to extract metadata using ffprobe when available
    func extractMetadataForItem(_ item: DownloadItem) {
        // Determine file path
        guard let output = item.outputFile ?? item.outputPath else { return }
        var targetPath = output
        // If output is a directory, try to pick latest matching file
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: targetPath, isDirectory: &isDir), isDir.boolValue {
            // find files matching expected extensions
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: targetPath)
                let candidates = contents.filter { $0.lowercased().hasSuffix(".mp3") || $0.lowercased().hasSuffix(".flac") }
                if let latest = candidates.sorted().last {
                    targetPath = (targetPath as NSString).appendingPathComponent(latest)
                }
            } catch { }
        }

        // Try ffprobe first
        var probePath: String? = nil
        if !self.ffmpegPath.isEmpty {
            let ffDir = (self.ffmpegPath as NSString).deletingLastPathComponent
            let candidate = (ffDir as NSString).appendingPathComponent("ffprobe.exe")
            if FileManager.default.isExecutableFile(atPath: candidate) {
                probePath = candidate
            }
        }
        // Try where.exe to find ffprobe on PATH
        if probePath == nil {
            let where = Process()
            where.executableURL = URL(fileURLWithPath: "C:/Windows/System32/where.exe")
            where.arguments = ["ffprobe.exe"]
            let pipe = Pipe()
            where.standardOutput = pipe
            do {
                try where.run()
                where.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty {
                    probePath = path
                }
            } catch { }
        }

        guard let probe = probePath else { return }

        let p = Process()
        p.executableURL = URL(fileURLWithPath: probe)
        p.arguments = ["-v", "quiet", "-print_format", "json", "-show_format", targetPath]
        let out = Pipe()
        p.standardOutput = out
        do {
            try p.run()
            p.waitUntilExit()
            let d = out.fileHandleForReading.readDataToEndOfFile()
            if let s = String(data: d, encoding: .utf8), let jsonData = s.data(using: .utf8) {
                if let obj = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any], let format = obj["format"] as? [String: Any] {
                    var meta: [String: String] = [:]
                    if let tags = format["tags"] as? [String: Any] {
                        for (k, v) in tags {
                            if let vs = v as? String { meta[k.lowercased()] = vs }
                        }
                    }
                    if let durationStr = format["duration"] as? String, let dur = Double(durationStr) {
                        meta["duration"] = formatDuration(seconds: dur)
                    }
                    DispatchQueue.main.async {
                        for (k, v) in meta { item.metadata[k] = v }
                        if let t = meta["title"] { item.title = t }
                        item.outputFile = targetPath
                    }
                }
            }
        } catch { }
    }

    // Show a Windows folder picker using PowerShell and capture the selected path
    func pickFolder(completion: @escaping (String?) -> Void) {
        #if os(Windows)
        let script = "Add-Type -AssemblyName System.Windows.Forms; $f = New-Object System.Windows.Forms.FolderBrowserDialog; $f.ShowNewFolderButton = $true; if ($f.ShowDialog() -eq 'OK') { Write-Output $f.SelectedPath }"
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe")
        task.arguments = ["-NoProfile", "-Command", script]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty {
                DispatchQueue.main.async { self.saveLocation = path; completion(path) }
                return
            }
        } catch { }
        DispatchQueue.main.async { completion(nil) }
        #else
        DispatchQueue.main.async { completion(nil) }
        #endif
    }

    // If an artwork image exists next to the downloaded file and ffmpeg is available,
    // embed it into MP3 files if not already present.
    func embedArtworkIfNeeded(item: DownloadItem) {
        guard let out = item.outputFile ?? item.outputPath else { return }
        let fileURL = URL(fileURLWithPath: out)
        let ext = fileURL.pathExtension.lowercased()
        guard ext == "mp3" || ext == "flac" else { return }

        // look for image files with same base name
        let base = fileURL.deletingPathExtension().path
        let possibleImgs = ["jpg", "jpeg", "png"].map { base + ".\($0)" }
        var foundImg: String? = nil
        for p in possibleImgs {
            if FileManager.default.fileExists(atPath: p) {
                foundImg = p; break
            }
        }

        guard let img = foundImg else { return }
        guard isFfmpegInstalled && !ffmpegPath.isEmpty else { return }

        // Check if mp3 already has attached picture by probing
        var hasArtwork = false
        let probe = Process()
        probe.executableURL = URL(fileURLWithPath: ffmpegPath)
        probe.arguments = ["-i", out]
        let errPipe = Pipe()
        probe.standardError = errPipe
        do {
            try probe.run()
            probe.waitUntilExit()
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            if let err = String(data: errData, encoding: .utf8), err.lowercased().contains("attached picture") || err.lowercased().contains("cover") {
                hasArtwork = true
            }
        } catch { }

        if hasArtwork { return }

        // Create a temp output file then replace original
        let temp = (out as NSString).appendingPathExtension("temp") ?? out + ".temp"
        let ff = Process()
        ff.executableURL = URL(fileURLWithPath: ffmpegPath)
        ff.arguments = ["-y", "-i", out, "-i", img, "-map", "0", "-map", "1", "-c", "copy", "-id3v2_version", "3", temp]
        do {
            try ff.run()
            ff.waitUntilExit()
            if ff.terminationStatus == 0 {
                // replace file
                try? FileManager.default.removeItem(atPath: out)
                try? FileManager.default.moveItem(atPath: temp, toPath: out)
            } else {
                try? FileManager.default.removeItem(atPath: temp)
            }
        } catch { }
    }

    private func performDownload(item: DownloadItem) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: self.ytDlpPath)

        var args: [String] = []
        args += ["-f", "bestaudio"]
        args += ["-x"]
        args += ["--audio-format", self.audioFormat]
        if self.audioFormat == "mp3" {
            args += ["--audio-quality", self.audioQuality]
        }
        args += ["--embed-thumbnail", "--add-metadata"]
        args += ["-o", "\(self.saveLocation)/%(title)s.%(ext)s"]
        args += ["--newline", "--no-playlist", item.url]
        task.arguments = args

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        DispatchQueue.main.async {
            item.status = .downloading
        }

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8) {
                self.parseYtDlpOutput(output: output, item: item)
            }
        }

        do {
            try task.run()
            task.waitUntilExit()
            pipe.fileHandleForReading.readabilityHandler = nil

            if task.terminationStatus == 0 {
                DispatchQueue.main.async {
                    item.status = .completed
                    item.progress = 1.0
                    item.outputPath = self.saveLocation
                }
                // After successful download, extract metadata and attempt to embed artwork if missing
                DispatchQueue.global(qos: .utility).async {
                    self.extractMetadataForItem(item)
                    self.embedArtworkIfNeeded(item: item)
                    self.notify(title: "Download complete", body: item.title)
                }
            } else {
                DispatchQueue.main.async {
                    item.status = .failed
                    item.error = "yt-dlp exited with non-zero status"
                }
            }
        } catch {
            DispatchQueue.main.async {
                item.status = .failed
                item.error = error.localizedDescription
            }
        }
    }

    private func parseYtDlpOutput(output: String, item: DownloadItem) {
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("[download] Destination:") {
                if let range = line.range(of: "Destination:") {
                    let pathStr = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
                    let full = String(pathStr)
                    DispatchQueue.main.async {
                        item.outputFile = full
                        let fn = URL(fileURLWithPath: full).deletingPathExtension().lastPathComponent
                        if !fn.isEmpty { item.title = fn }
                    }
                }
            }
            if line.contains("%") && line.contains("[download]") {
                let comps = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                for comp in comps {
                    if comp.contains("%") {
                        let percentString = comp.replacingOccurrences(of: "%", with: "")
                        if let percent = Double(percentString) {
                            DispatchQueue.main.async {
                                item.progress = percent / 100.0
                            }
                        }
                    }
                }
            }
        }
    }
}
