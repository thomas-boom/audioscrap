//
//  DownloadManager.swift
//  audioscrap
//
//  Created by Thomas Boom on 12/8/25.
//

import Foundation
import SwiftUI
import Combine
import UserNotifications
import AppKit

class DownloadManager: NSObject, ObservableObject {
    @Published var downloads: [DownloadItem] = []
    @Published var isYtDlpInstalled = false
    @Published var ytDlpPath: String = ""
    @Published var ytDlpCandidatePath: String? = nil
    @Published var ytDlpResolvedCandidatePath: String? = nil
    @Published var ytDlpFoundButNotExecutable: Bool = false
    @Published var saveLocation: String {
        didSet {
            UserDefaults.standard.set(self.saveLocation, forKey: "saveLocation")
        }
    }
    @Published var statusMessage: String = "Idle"
    @Published var lastOutput: String = ""
    @Published var isBrewAvailable: Bool = false
    @Published var brewPath: String = ""
    @Published var brewPrefix: String = ""
    // Allow user-selectable output audio format (defaults to mp3)
    @Published var audioFormat: String = "mp3" {
        didSet {
            UserDefaults.standard.set(self.audioFormat, forKey: "audioFormat")
        }
    }
    // Only provide the formats requested by the user. Limit to mp3
    // because bitrate options only work reliably for mp3 conversions.
    let availableAudioFormats: [String] = ["mp3"]
    // Audio quality options for yt-dlp (value is passed to --audio-quality)
    @Published var audioQuality: String = "0" {
        didSet {
            UserDefaults.standard.set(self.audioQuality, forKey: "audioQuality")
        }
    }
    let availableAudioQualityOptions: [(label: String, value: String)] = [
        ("Best (0)", "0"),
        ("320k", "320k"),
        ("256k", "256k"),
        ("192k", "192k"),
        ("128k", "128k")
    ]
    // Deno runtime detection (yt-dlp now requires Deno for some features)
    @Published var isDenoInstalled: Bool = false
    @Published var denoPath: String = ""
    @Published var denoCandidatePath: String? = nil
    @Published var denoResolvedCandidatePath: String? = nil
    // ffmpeg detection
    @Published var isFfmpegInstalled: Bool = false
    @Published var ffmpegPath: String = ""
    @Published var ffmpegCandidatePath: String? = nil
    @Published var ffmpegResolvedCandidatePath: String? = nil
    
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        // Default to Downloads folder
        let downloadsPath = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? NSHomeDirectory()
        self.saveLocation = downloadsPath
        // Finish superclass initialization before using self as notification delegate
        super.init()

        // Request notification permission and then check installation
        requestNotificationPermission()
        // Run checks off the main thread to avoid publishing during view updates
        DispatchQueue.global(qos: .background).async {
            // Detect brew executable and prefix synchronously in background, publish result on main, then use prefix
            let detected = self.detectBrewExecAndPrefixSync()
            DispatchQueue.main.async {
                if let (execPath, prefix) = detected {
                    self.isBrewAvailable = true
                    self.brewPath = execPath
                    self.brewPrefix = prefix
                } else {
                    self.isBrewAvailable = false
                    self.brewPath = ""
                    self.brewPrefix = ""
                }
            }

            self.checkYtDlpInstallation(brewPrefix: detected?.1)
            // Also check for Deno runtime and ffmpeg after yt-dlp check
            self.checkDenoInstallation(brewPrefix: detected?.1)
            self.checkFfmpegInstallation(brewPrefix: detected?.1)
        }

        // Load persisted user preferences (audio format, quality and save location)
        DispatchQueue.main.async {
            if let savedFormat = UserDefaults.standard.string(forKey: "audioFormat") {
                self.audioFormat = savedFormat
            }
            if let savedQuality = UserDefaults.standard.string(forKey: "audioQuality") {
                self.audioQuality = savedQuality
            }
            if let savedLocation = UserDefaults.standard.string(forKey: "saveLocation"), !savedLocation.isEmpty {
                // Only adopt the saved location if the path actually exists; otherwise keep default
                if FileManager.default.fileExists(atPath: savedLocation) {
                    self.saveLocation = savedLocation
                } else {
                    // If saved path doesn't exist, ignore and keep default Downloads folder
                    print("[AudioScrap DEBUG] saved saveLocation does not exist: \(savedLocation)")
                }
            }
        }
    }

    /// Check for ffmpeg. If `brewPrefix` is provided, check that prefix's bin directory as well.
    func checkFfmpegInstallation(brewPrefix: String? = nil) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = ["ffmpeg"]

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
            } else {
                var found: String? = nil
                if let envPath = ProcessInfo.processInfo.environment["PATH"] {
                    let dirs = envPath.split(separator: ":").map { String($0) }
                    for dir in dirs {
                        let candidate = (dir as NSString).appendingPathComponent("ffmpeg")
                        if FileManager.default.isExecutableFile(atPath: candidate) {
                            found = candidate
                            break
                        }
                    }
                }

                if found == nil, let brewPrefix = brewPrefix {
                    let candidate = (brewPrefix as NSString).appendingPathComponent("bin/ffmpeg")
                    if FileManager.default.isExecutableFile(atPath: candidate) {
                        found = candidate
                    } else {
                        // check cellar lib path
                        let cellarBase = (brewPrefix as NSString).appendingPathComponent("Cellar/ffmpeg")
                        if FileManager.default.fileExists(atPath: cellarBase) {
                            do {
                                let versions = try FileManager.default.contentsOfDirectory(atPath: cellarBase)
                                for ver in versions {
                                    let binPath = (cellarBase as NSString).appendingPathComponent((ver as NSString).appendingPathComponent("bin/ffmpeg"))
                                    if FileManager.default.isExecutableFile(atPath: binPath) {
                                        found = binPath
                                        break
                                    }
                                }
                            } catch {
                                // ignore
                            }
                        }
                    }
                }

                if found == nil {
                    let possible = ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/home/linuxbrew/.linuxbrew/bin/ffmpeg"]
                    for p in possible {
                        if FileManager.default.fileExists(atPath: p) {
                            let resolved = URL(fileURLWithPath: p).resolvingSymlinksInPath().path
                            if FileManager.default.isExecutableFile(atPath: resolved) {
                                found = resolved
                                break
                            } else {
                                DispatchQueue.main.async {
                                    self.ffmpegCandidatePath = p
                                    self.ffmpegResolvedCandidatePath = resolved
                                }
                            }
                        }
                    }
                }

                DispatchQueue.main.async {
                    if let found = found {
                        let resolved = URL(fileURLWithPath: found).resolvingSymlinksInPath().path
                        self.isFfmpegInstalled = true
                        self.ffmpegPath = resolved
                        self.statusMessage = "ffmpeg found: \(found) -> \(resolved)"
                    } else {
                        self.isFfmpegInstalled = false
                        print("[AudioScrap DEBUG] ffmpeg not found")
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.isFfmpegInstalled = false
            }
        }
    }

    /// Check for Deno runtime. If `brewPrefix` is provided, check that prefix's bin directory as well.
    func checkDenoInstallation(brewPrefix: String? = nil) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = ["deno"]

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
            } else {
                // Try PATH directories manually
                var found: String? = nil
                if let envPath = ProcessInfo.processInfo.environment["PATH"] {
                    let dirs = envPath.split(separator: ":").map { String($0) }
                    for dir in dirs {
                        let candidate = (dir as NSString).appendingPathComponent("deno")
                        if FileManager.default.isExecutableFile(atPath: candidate) {
                            found = candidate
                            break
                        }
                    }
                }

                // Check brew prefix bin
                if found == nil, let brewPrefix = brewPrefix {
                    let candidate = (brewPrefix as NSString).appendingPathComponent("bin/deno")
                    if FileManager.default.isExecutableFile(atPath: candidate) {
                        found = candidate
                    }
                }

                // Check common locations
                if found == nil {
                    let possible = ["/opt/homebrew/bin/deno", "/usr/local/bin/deno", "/home/linuxbrew/.linuxbrew/bin/deno"]
                    for p in possible {
                        if FileManager.default.fileExists(atPath: p) {
                            let resolved = URL(fileURLWithPath: p).resolvingSymlinksInPath().path
                            if FileManager.default.isExecutableFile(atPath: resolved) {
                                found = resolved
                                break
                            } else {
                                DispatchQueue.main.async {
                                    self.denoCandidatePath = p
                                    self.denoResolvedCandidatePath = resolved
                                }
                            }
                        }
                    }
                }

                DispatchQueue.main.async {
                    if let found = found {
                        let resolved = URL(fileURLWithPath: found).resolvingSymlinksInPath().path
                        self.isDenoInstalled = true
                        self.denoPath = resolved
                        self.statusMessage = "deno found: \(found) -> \(resolved)"
                    } else {
                        self.isDenoInstalled = false
                        // don't notify every time; user already notified about yt-dlp missing earlier
                        print("[AudioScrap DEBUG] deno not found")
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.isDenoInstalled = false
            }
        }
    }

    /// Detect Homebrew executable path and its prefix synchronously (run off the main thread).
    /// Returns tuple (execPath, prefix) if found, otherwise nil.
    func detectBrewExecAndPrefixSync() -> (String, String)? {
        // First try `which brew`
        let which = Process()
        which.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        which.arguments = ["brew"]
        var execPath: String? = nil
        var pipe = Pipe()
        which.standardOutput = pipe
        do {
            try which.run()
            which.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty {
                execPath = path
            }
        } catch {
            // ignore
        }

        // If which didn't find it, check common locations for brew executable
        if execPath == nil {
            let possibleExecs = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew", "/home/linuxbrew/.linuxbrew/bin/brew"]
            for p in possibleExecs {
                if FileManager.default.isExecutableFile(atPath: p) {
                    execPath = p
                    break
                }
            }
        }

        guard let exec = execPath else { return nil }

        // Try to get prefix by running `brew --prefix`
        let brewTask = Process()
        brewTask.executableURL = URL(fileURLWithPath: exec)
        brewTask.arguments = ["--prefix"]
        pipe = Pipe()
        brewTask.standardOutput = pipe
        do {
            try brewTask.run()
            brewTask.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let prefix = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !prefix.isEmpty {
                return (exec, prefix)
            }
        } catch {
            // ignore
        }

        // If brew --prefix failed, derive prefix from exec path by removing /bin/brew
        if exec.hasSuffix("/bin/brew") {
            let prefix = String(exec.dropLast("/bin/brew".count))
            return (exec, prefix)
        }

        return (exec, "")
    }

    /// Detect Homebrew path synchronously (can be run off the main thread).
    /// Returns the path to the `brew` executable if found, otherwise nil.
    func detectBrewPathSync() -> String? {
        let which = Process()
        which.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        which.arguments = ["brew"]
        let pipe = Pipe()
        which.standardOutput = pipe
        do {
            try which.run()
            which.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty {
                return path
            }
        } catch {
            // ignore
        }

        // check common locations
        let possiblePaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew", "/home/linuxbrew/.linuxbrew/bin/brew"]
        for p in possiblePaths {
            if FileManager.default.isExecutableFile(atPath: p) {
                return p
            }
        }
        return nil
    }

    func checkBrewInstallation() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = ["brew"]

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty {
                DispatchQueue.main.async {
                    self.isBrewAvailable = true
                    self.brewPath = path
                }
            } else {
                // check common brew locations (Apple Silicon and Intel)
                let possiblePaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew", "/home/linuxbrew/.linuxbrew/bin/brew"]
                var found: String? = nil
                for p in possiblePaths {
                    if FileManager.default.isExecutableFile(atPath: p) {
                        found = p
                        break
                    }
                }
                DispatchQueue.main.async {
                    if let found = found {
                        self.isBrewAvailable = true
                        self.brewPath = found
                    } else {
                        self.isBrewAvailable = false
                        self.brewPath = ""
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.isBrewAvailable = false
                self.brewPath = ""
            }
        }
    }
    
    /// Check for yt-dlp. If `brewPrefix` is provided, check that prefix's bin directory as well.
    func checkYtDlpInstallation(brewPrefix: String? = nil) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = ["yt-dlp"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty {
                DispatchQueue.main.async {
                    self.isYtDlpInstalled = true
                    self.ytDlpPath = path
                }
            } else {
                // If which didn't find it, try searching PATH directories
                var found: String? = nil
                if let envPath = ProcessInfo.processInfo.environment["PATH"] {
                    let dirs = envPath.split(separator: ":").map { String($0) }
                    for dir in dirs {
                        let candidate = (dir as NSString).appendingPathComponent("yt-dlp")
                        if FileManager.default.isExecutableFile(atPath: candidate) {
                            found = candidate
                            break
                        }
                    }
                }

                // If not found in PATH, check provided brewPrefix (if any)
                if found == nil, let brewPrefix = brewPrefix {
                    // First check the usual bin location
                    let candidate = (brewPrefix as NSString).appendingPathComponent("bin/yt-dlp")
                    if FileManager.default.isExecutableFile(atPath: candidate) {
                        found = candidate
                    } else {
                        // Homebrew sometimes installs executables under Cellar/<pkg>/<version>/libexec
                        let cellarBase = (brewPrefix as NSString).appendingPathComponent("Cellar/yt-dlp")
                        if FileManager.default.fileExists(atPath: cellarBase) {
                            do {
                                let versions = try FileManager.default.contentsOfDirectory(atPath: cellarBase)
                                for ver in versions {
                                    let libexecPath = (cellarBase as NSString).appendingPathComponent((ver as NSString).appendingPathComponent("libexec/bin/yt-dlp"))
                                    if FileManager.default.isExecutableFile(atPath: libexecPath) {
                                        found = libexecPath
                                        break
                                    }
                                }
                            } catch {
                                // ignore
                            }
                        }
                    }
                }

                // Still not found? check common locations and explicit Homebrew paths
                if found == nil {
                    let possiblePaths = ["/opt/homebrew/bin/yt-dlp", "/usr/local/bin/yt-dlp", "/home/linuxbrew/.linuxbrew/bin/yt-dlp"]
                    for p in possiblePaths {
                        // If file exists at path (even if symlink), try resolving
                        if FileManager.default.fileExists(atPath: p) {
                            // Resolve symlink to actual file
                            let resolved = URL(fileURLWithPath: p).resolvingSymlinksInPath().path
                            if FileManager.default.isExecutableFile(atPath: resolved) {
                                found = p
                                print("[AudioScrap DEBUG] found candidate: \(p) resolved -> \(resolved)")
                                break
                            } else {
                                // record non-executable candidate for UI
                                DispatchQueue.main.async {
                                    self.ytDlpCandidatePath = p
                                    self.ytDlpResolvedCandidatePath = resolved
                                    self.ytDlpFoundButNotExecutable = true
                                }
                                print("[AudioScrap DEBUG] candidate exists but not executable: \(p) -> \(resolved)")
                            }
                        } else {
                            // Debug: candidate not present
                            print("[AudioScrap DEBUG] candidate not present: \(p)")
                        }
                    }
                }

                // Also check common Cellar libexec locations if still not found
                if found == nil {
                    let cellarBases = ["/opt/homebrew/Cellar/yt-dlp", "/usr/local/Cellar/yt-dlp"]
                    for cellarBase in cellarBases {
                        if FileManager.default.fileExists(atPath: cellarBase) {
                            do {
                                let versions = try FileManager.default.contentsOfDirectory(atPath: cellarBase)
                                for ver in versions {
                                    let libexecPath = (cellarBase as NSString).appendingPathComponent((ver as NSString).appendingPathComponent("libexec/bin/yt-dlp"))
                                    if FileManager.default.fileExists(atPath: libexecPath) {
                                        let resolved = URL(fileURLWithPath: libexecPath).resolvingSymlinksInPath().path
                                                if FileManager.default.isExecutableFile(atPath: resolved) {
                                                    found = libexecPath
                                                    print("[AudioScrap DEBUG] found in cellar libexec: \(libexecPath) -> \(resolved)")
                                                    break
                                                } else {
                                                    // record non-executable candidate for UI
                                                    DispatchQueue.main.async {
                                                        self.ytDlpCandidatePath = libexecPath
                                                        self.ytDlpResolvedCandidatePath = resolved
                                                        self.ytDlpFoundButNotExecutable = true
                                                    }
                                                    print("[AudioScrap DEBUG] cellar candidate not executable: \(libexecPath) -> \(resolved)")
                                                }
                                    }
                                }
                                if found != nil { break }
                            } catch {
                                // ignore
                            }
                        } else {
                            print("[AudioScrap DEBUG] cellar base not present: \(cellarBase)")
                        }
                    }
                }
                DispatchQueue.main.async {
                    if let found = found {
                        // Resolve symlinks to the actual binary location when possible
                        let resolved = URL(fileURLWithPath: found).resolvingSymlinksInPath().path
                        self.isYtDlpInstalled = true
                        self.ytDlpPath = resolved
                        if resolved != found {
                            self.statusMessage = "yt-dlp found: \(found) -> \(resolved)"
                        } else {
                            self.statusMessage = "yt-dlp found: \(found)"
                        }
                        // DEBUG: print detection info
                        print("[AudioScrap DEBUG] brewPrefix=\(self.brewPrefix) detected yt-dlp at: \(found) resolved -> \(resolved)")
                    } else {
                        self.isYtDlpInstalled = false
                        self.statusMessage = "yt-dlp not found"
                        // Notify user that yt-dlp is not installed
                        self.notifyYtDlpNotInstalled()
                        // DEBUG: print negative detection with brewPrefix
                        print("[AudioScrap DEBUG] brewPrefix=\(self.brewPrefix) yt-dlp NOT found (checked PATH, brew prefix, and common locations)")
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.isYtDlpInstalled = false
                self.notifyYtDlpNotInstalled()
            }
        }
    }

    // Public helpers for UI actions
    func copyBrewCommandToClipboard() {
        DispatchQueue.main.async {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("brew install yt-dlp", forType: .string)
            self.statusMessage = "Brew command copied"
        }
    }

    func copyHomebrewInstallCommandToClipboard() {
        let cmd = "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        DispatchQueue.main.async {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(cmd, forType: .string)
            self.statusMessage = "Homebrew install command copied"
        }
    }

    func openHomebrewSite() {
        DispatchQueue.main.async {
            if let url = URL(string: "https://brew.sh") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    func openYtDlpInFinder() {
        DispatchQueue.main.async {
            // Prefer resolved executable path, fall back to candidate path
            let path = self.ytDlpPath.isEmpty ? (self.ytDlpResolvedCandidatePath ?? self.ytDlpCandidatePath) : self.ytDlpPath
            guard let path = path else { return }
            let url = URL(fileURLWithPath: path)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    /// Attempt to make the candidate executable (chmod +x). Returns true on success.
    func makeYtDlpExecutable() {
        // choose the resolved candidate path if available, else the candidate
        guard let target = ytDlpResolvedCandidatePath ?? ytDlpCandidatePath else {
            DispatchQueue.main.async { self.statusMessage = "No candidate to fix" }
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.launchPath = "/bin/chmod"
            task.arguments = ["+x", target]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe
            do {
                try task.run()
                task.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let out = String(data: data, encoding: .utf8) ?? ""
                DispatchQueue.main.async {
                    if FileManager.default.isExecutableFile(atPath: target) {
                        self.ytDlpFoundButNotExecutable = false
                        self.ytDlpPath = target
                        self.statusMessage = "Made yt-dlp executable"
                        self.postSimpleNotification(title: "Fixed", body: "yt-dlp is now executable")
                    } else {
                        self.statusMessage = "Failed to make executable"
                        self.lastOutput = out
                        self.postSimpleNotification(title: "Fix failed", body: "Failed to set executable permission")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusMessage = "chmod error: \(error.localizedDescription)"
                    self.postSimpleNotification(title: "Fix error", body: error.localizedDescription)
                }
            }
        }
    }

    func copyChmodCommandToClipboard() {
        guard let target = ytDlpResolvedCandidatePath ?? ytDlpCandidatePath else { return }
        let cmd = "chmod +x \"\(target)\""
        DispatchQueue.main.async {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(cmd, forType: .string)
            self.statusMessage = "chmod command copied"
        }
    }

    // MARK: - Deno remediation helpers (mirror yt-dlp actions)
    func copyDenoChmodCommandToClipboard() {
        guard let target = denoResolvedCandidatePath ?? denoCandidatePath else { return }
        let cmd = "chmod +x \"\(target)\""
        DispatchQueue.main.async {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(cmd, forType: .string)
            self.statusMessage = "chmod command copied"
        }
    }

    /// Attempt to make Deno executable
    func makeDenoExecutable() {
        guard let target = denoResolvedCandidatePath ?? denoCandidatePath else {
            DispatchQueue.main.async { self.statusMessage = "No Deno candidate to fix" }
            return
            
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.launchPath = "/bin/chmod"
            task.arguments = ["+x", target]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe
            do {
                try task.run()
                task.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let out = String(data: data, encoding: .utf8) ?? ""
                DispatchQueue.main.async {
                    if FileManager.default.isExecutableFile(atPath: target) {
                        self.isDenoInstalled = true
                        self.denoPath = target
                        self.statusMessage = "Made deno executable"
                        self.postSimpleNotification(title: "Fixed", body: "deno is now executable")
                    } else {
                        self.statusMessage = "Failed to make deno executable"
                        self.lastOutput = out
                        self.postSimpleNotification(title: "Fix failed", body: "Failed to set executable permission for deno")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusMessage = "chmod error: \(error.localizedDescription)"
                    self.postSimpleNotification(title: "Fix error", body: error.localizedDescription)
                }
            }
        }
    }

    /// Open Terminal.app and run the chmod command for Deno interactively.
    func openTerminalAndRunDenoChmod() {
        guard let target = denoResolvedCandidatePath ?? denoCandidatePath else {
            DispatchQueue.main.async { self.statusMessage = "No Deno candidate to run in Terminal" }
            return
        }
        let chmodCmd = "chmod +x \"\(target)\""
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        let activate = "tell application \"Terminal\" to activate"
        let escapedCmd = chmodCmd.replacingOccurrences(of: "\"", with: "\\\"")
        let runLine = "tell application \"Terminal\" to do script \"\(escapedCmd)\""
        task.arguments = ["-e", activate, "-e", runLine]

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try task.run()
                task.waitUntilExit()
                DispatchQueue.main.async {
                    self.statusMessage = "Opened Terminal — command sent"
                    self.postSimpleNotification(title: "Terminal opened", body: "Run the chmod command in the Terminal window if necessary.")
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusMessage = "Failed to open Terminal: \(error.localizedDescription)"
                    self.postSimpleNotification(title: "Error", body: "Failed to open Terminal to run chmod for deno")
                }
            }
        }
    }

    func openDenoInFinder() {
        DispatchQueue.main.async {
            let path = self.denoPath.isEmpty ? (self.denoResolvedCandidatePath ?? self.denoCandidatePath) : self.denoPath
            guard let path = path else { return }
            let url = URL(fileURLWithPath: path)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    func copyDenoBrewCommandToClipboard() {
        DispatchQueue.main.async {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("brew install deno", forType: .string)
            self.statusMessage = "Brew command copied"
        }
    }

    func installDenoViaBrew() {
        guard isBrewAvailable else {
            DispatchQueue.main.async {
                self.statusMessage = "Homebrew not available — install Homebrew first"
                self.postSimpleNotification(title: "Homebrew missing", body: "Install Homebrew in Terminal.app: /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"")
            }
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            DispatchQueue.main.async { self.statusMessage = "Installing deno..." }
            let task = Process()
            task.launchPath = "/bin/bash"
            let brewCmd = self.brewPath.isEmpty ? "brew" : self.brewPath
            task.arguments = ["-lc", "\(brewCmd) install deno"]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe
            do {
                try task.run()
                task.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                DispatchQueue.main.async {
                    if task.terminationStatus == 0 {
                        self.statusMessage = "deno installed"
                        self.checkDenoInstallation()
                    } else {
                        self.statusMessage = "Install failed"
                        self.lastOutput = output
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusMessage = "Install error: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - ffmpeg remediation helpers
    func copyFfmpegChmodCommandToClipboard() {
        guard let target = ffmpegResolvedCandidatePath ?? ffmpegCandidatePath else { return }
        let cmd = "chmod +x \"\(target)\""
        DispatchQueue.main.async {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(cmd, forType: .string)
            self.statusMessage = "chmod command copied"
        }
    }

    func makeFfmpegExecutable() {
        guard let target = ffmpegResolvedCandidatePath ?? ffmpegCandidatePath else {
            DispatchQueue.main.async { self.statusMessage = "No ffmpeg candidate to fix" }
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.launchPath = "/bin/chmod"
            task.arguments = ["+x", target]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe
            do {
                try task.run()
                task.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let out = String(data: data, encoding: .utf8) ?? ""
                DispatchQueue.main.async {
                    if FileManager.default.isExecutableFile(atPath: target) {
                        self.isFfmpegInstalled = true
                        self.ffmpegPath = target
                        self.statusMessage = "Made ffmpeg executable"
                        self.postSimpleNotification(title: "Fixed", body: "ffmpeg is now executable")
                    } else {
                        self.statusMessage = "Failed to make ffmpeg executable"
                        self.lastOutput = out
                        self.postSimpleNotification(title: "Fix failed", body: "Failed to set executable permission for ffmpeg")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusMessage = "chmod error: \(error.localizedDescription)"
                    self.postSimpleNotification(title: "Fix error", body: error.localizedDescription)
                }
            }
        }
    }

    func openTerminalAndRunFfmpegChmod() {
        guard let target = ffmpegResolvedCandidatePath ?? ffmpegCandidatePath else {
            DispatchQueue.main.async { self.statusMessage = "No ffmpeg candidate to run in Terminal" }
            return
        }
        let chmodCmd = "chmod +x \"\(target)\""
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        let activate = "tell application \"Terminal\" to activate"
        let escapedCmd = chmodCmd.replacingOccurrences(of: "\"", with: "\\\"")
        let runLine = "tell application \"Terminal\" to do script \"\(escapedCmd)\""
        task.arguments = ["-e", activate, "-e", runLine]

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try task.run()
                task.waitUntilExit()
                DispatchQueue.main.async {
                    self.statusMessage = "Opened Terminal — command sent"
                    self.postSimpleNotification(title: "Terminal opened", body: "Run the chmod command in the Terminal window if necessary.")
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusMessage = "Failed to open Terminal: \(error.localizedDescription)"
                    self.postSimpleNotification(title: "Error", body: "Failed to open Terminal to run chmod for ffmpeg")
                }
            }
        }
    }

    func openFfmpegInFinder() {
        DispatchQueue.main.async {
            let path = self.ffmpegPath.isEmpty ? (self.ffmpegResolvedCandidatePath ?? self.ffmpegCandidatePath) : self.ffmpegPath
            guard let path = path else { return }
            let url = URL(fileURLWithPath: path)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    func copyFfmpegBrewCommandToClipboard() {
        DispatchQueue.main.async {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("brew install ffmpeg", forType: .string)
            self.statusMessage = "Brew command copied"
        }
    }

    func installFfmpegViaBrew() {
        guard isBrewAvailable else {
            DispatchQueue.main.async {
                self.statusMessage = "Homebrew not available — install Homebrew first"
                self.postSimpleNotification(title: "Homebrew missing", body: "Install Homebrew: /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"")
            }
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            DispatchQueue.main.async { self.statusMessage = "Installing ffmpeg..." }
            let task = Process()
            task.launchPath = "/bin/bash"
            let brewCmd = self.brewPath.isEmpty ? "brew" : self.brewPath
            task.arguments = ["-lc", "\(brewCmd) install ffmpeg"]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe
            do {
                try task.run()
                task.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                DispatchQueue.main.async {
                    if task.terminationStatus == 0 {
                        self.statusMessage = "ffmpeg installed"
                        self.checkFfmpegInstallation()
                    } else {
                        self.statusMessage = "Install failed"
                        self.lastOutput = output
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusMessage = "Install error: \(error.localizedDescription)"
                }
            }
        }
    }

    /// Open Terminal.app and run the chmod command interactively.
    func openTerminalAndRunChmod() {
        guard let target = ytDlpResolvedCandidatePath ?? ytDlpCandidatePath else {
            DispatchQueue.main.async { self.statusMessage = "No candidate to run in Terminal" }
            return
        }
        // Construct the chmod command and run it in Terminal via osascript
        let chmodCmd = "chmod +x \"\(target)\""
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        // Two -e arguments: activate Terminal, then run the command in a new window
        let activate = "tell application \"Terminal\" to activate"
        // Escape double quotes in the command for embedding in AppleScript
        let escapedCmd = chmodCmd.replacingOccurrences(of: "\"", with: "\\\"")
        let runLine = "tell application \"Terminal\" to do script \"\(escapedCmd)\""
        task.arguments = ["-e", activate, "-e", runLine]

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try task.run()
                task.waitUntilExit()
                DispatchQueue.main.async {
                    self.statusMessage = "Opened Terminal — command sent"
                    self.postSimpleNotification(title: "Terminal opened", body: "Run the chmod command in the Terminal window if necessary.")
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusMessage = "Failed to open Terminal: \(error.localizedDescription)"
                    self.postSimpleNotification(title: "Error", body: "Failed to open Terminal to run chmod")
                }
            }
        }
    }

    func installYtDlpViaBrew() {
        // Ensure Homebrew is available first
        guard isBrewAvailable else {
            DispatchQueue.main.async {
                self.statusMessage = "Homebrew not available — install Homebrew first"
                self.postSimpleNotification(title: "Homebrew missing", body: "Install Homebrew: /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"")
            }
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            DispatchQueue.main.async { self.statusMessage = "Installing yt-dlp..." }
            let task = Process()
            task.launchPath = "/bin/bash"
            // Use absolute brew path when available to avoid PATH issues
            let brewCmd = self.brewPath.isEmpty ? "brew" : self.brewPath
            task.arguments = ["-lc", "\(brewCmd) install yt-dlp"]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe
            do {
                try task.run()
                task.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                DispatchQueue.main.async {
                    if task.terminationStatus == 0 {
                        self.statusMessage = "yt-dlp installed"
                        self.checkYtDlpInstallation()
                    } else {
                        self.statusMessage = "Install failed"
                        self.lastOutput = output
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusMessage = "Install error: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Notifications
    private func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        // Set self as delegate to handle action responses
        DispatchQueue.main.async {
            center.delegate = self
        }

        // Register actions and categories
        let copyAction = UNNotificationAction(identifier: "COPY_COMMAND", title: "Copy Command", options: [])
        let openAction = UNNotificationAction(identifier: "OPEN_HOMEBREW", title: "Open Homebrew", options: [.foreground])
        let installAction = UNNotificationAction(identifier: "INSTALL_BREW", title: "Install", options: [.authenticationRequired])
        let category = UNNotificationCategory(identifier: "YT_DLP_MISSING", actions: [copyAction, openAction, installAction], intentIdentifiers: [], options: [])
        center.setNotificationCategories([category])

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
            // No further action needed; notifications will proceed only if granted
        }
    }

    func notifyYtDlpNotInstalled() {
        let center = UNUserNotificationCenter.current()
        // Check current settings to avoid unnecessary notifications
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "yt-dlp not found"
            content.body = "yt-dlp is not installed. Install with Homebrew: brew install yt-dlp"
            content.sound = .default
            // Use category to expose actions
            content.categoryIdentifier = "YT_DLP_MISSING"

            // Deliver immediately
            let request = UNNotificationRequest(identifier: "yt-dlp-missing", content: content, trigger: nil)
            center.add(request) { error in
                if let error = error {
                    print("Failed to post notification: \(error.localizedDescription)")
                }
            }
        }
    }

    // Helper to post a follow-up notification
    private func postSimpleNotification(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request) { error in
            if let error = error {
                print("Failed to post notification: \(error.localizedDescription)")
            }
        }
    }

}

// MARK: - UNUserNotificationCenterDelegate
extension DownloadManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let id = response.actionIdentifier
        switch id {
        case "COPY_COMMAND":
            // Copy brew command to clipboard
            DispatchQueue.main.async {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("brew install yt-dlp", forType: .string)
                self.postSimpleNotification(title: "Copied", body: "brew install yt-dlp copied to clipboard")
            }
        case "OPEN_HOMEBREW":
            DispatchQueue.main.async {
                if let url = URL(string: "https://brew.sh") {
                    NSWorkspace.shared.open(url)
                }
            }
        case "INSTALL_BREW":
            // Try to run brew install yt-dlp
            DispatchQueue.global(qos: .userInitiated).async {
                let task = Process()
                task.launchPath = "/bin/bash"
                task.arguments = ["-lc", "brew install yt-dlp"]
                let pipe = Pipe()
                task.standardOutput = pipe
                task.standardError = pipe
                do {
                    try task.run()
                    task.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    DispatchQueue.main.async {
                        if task.terminationStatus == 0 {
                            self.postSimpleNotification(title: "Installed", body: "yt-dlp installed successfully")
                            // Recheck installation to update state
                            self.checkYtDlpInstallation()
                        } else {
                            self.postSimpleNotification(title: "Install Failed", body: "Failed to install yt-dlp. Check Terminal for details.")
                            print("brew install output: \(output)")
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.postSimpleNotification(title: "Install Error", body: error.localizedDescription)
                    }
                }
            }
        default:
            break
        }

        completionHandler()
    }
    
    func addDownload(url: String, platform: Platform = .auto) {
        let item = DownloadItem(url: url, platform: platform)
        // Append on main thread with animation so UI can transition the new row
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.8)) {
                self.downloads.append(item)
            }
        }
        // Start download (can run concurrently)
        startDownload(item: item)
    }
    
    func removeDownload(item: DownloadItem) {
        downloads.removeAll { $0.id == item.id }
    }
    
    func clearCompleted() {
        downloads.removeAll { $0.status == .completed }
    }
    
    private func startDownload(item: DownloadItem) {
        guard isYtDlpInstalled else {
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.25)) {
                    item.status = .failed
                }
                item.error = "yt-dlp is not installed. Please install it using Homebrew: brew install yt-dlp"
            }
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.performDownload(item: item)
        }
    }
    
    private func performDownload(item: DownloadItem) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: self.ytDlpPath)
        
        // Use user-selected save location
        let outputPath = self.saveLocation
        
        // Arguments for yt-dlp to extract highest quality audio in user-selected format
        task.arguments = [
            "-f", "bestaudio",  // Download best available audio quality
            "-x",  // Extract audio
            "--audio-format", self.audioFormat,  // Convert to selected format (mp3, m4a, etc.)
            "--audio-quality", self.audioQuality,  // User-selected audio quality (0 = best, or e.g. 320k)
            "--embed-thumbnail",  // Embed thumbnail as album art
            "--add-metadata",  // Add metadata to file
            "-o", "\(outputPath)/%(title)s.%(ext)s",  // Output template
            "--newline",  // Progress on new lines
            "--no-playlist",  // Don't download playlists
            item.url
        ]
        
        // Ensure yt-dlp can find Deno by adding deno's directory to PATH when available
        var env = ProcessInfo.processInfo.environment
        // Prepend ffmpeg and deno dirs to PATH when available so yt-dlp can find them
        var pathComponents: [String] = []
        if !self.ffmpegPath.isEmpty {
            let ffmpegDir = (self.ffmpegPath as NSString).deletingLastPathComponent
            pathComponents.append(ffmpegDir)
        }
        if !self.denoPath.isEmpty {
            let denoDir = (self.denoPath as NSString).deletingLastPathComponent
            pathComponents.append(denoDir)
        }
        if !pathComponents.isEmpty {
            let prefix = pathComponents.joined(separator: ":")
            if let existing = env["PATH"] {
                env["PATH"] = "\(prefix):\(existing)"
            } else {
                env["PATH"] = prefix
            }
            DispatchQueue.main.async {
                self.statusMessage = "Using tools from: \(prefix)"
            }
        }
        task.environment = env

        let pipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = pipe
        task.standardError = errorPipe
        
        // Update status
        DispatchQueue.main.async {
            withAnimation(.easeIn(duration: 0.22)) {
                item.status = .downloading
            }
        }
        
        // Read output continuously
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
                    withAnimation(.easeOut(duration: 0.3)) {
                        item.status = .completed
                        item.progress = 1.0
                    }
                    item.outputPath = outputPath
                    // Play a short completion sound
                    NSSound.beep()
                }
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                DispatchQueue.main.async {
                    withAnimation(.easeIn(duration: 0.2)) {
                        item.status = .failed
                    }
                    item.error = errorMessage
                }
            }
        } catch {
            DispatchQueue.main.async {
                withAnimation(.easeIn(duration: 0.2)) {
                    item.status = .failed
                }
                item.error = error.localizedDescription
            }
        }
    }
    
    private func parseYtDlpOutput(output: String, item: DownloadItem) {
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            // Append to live output log (keep it reasonably short)
            DispatchQueue.main.async {
                let appended = (self.lastOutput.isEmpty ? "" : "\n") + line
                let maxLen = 4000
                let new = (self.lastOutput + appended)
                if new.count > maxLen {
                    // keep last maxLen characters
                    let start = new.index(new.endIndex, offsetBy: -maxLen)
                    self.lastOutput = String(new[start...])
                } else {
                    self.lastOutput = new
                }
            }
            // Parse title from output
                if line.contains("[download] Destination:") {
                let components = line.components(separatedBy: "/")
                if let filename = components.last?.replacingOccurrences(of: ".mp3", with: "") {
                    DispatchQueue.main.async {
                        item.title = filename
                    }
                }
            }
            
            // Parse progress
                if line.contains("[download]") && line.contains("%") {
                let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                for component in components {
                    if component.contains("%") {
                        let percentString = component.replacingOccurrences(of: "%", with: "")
                        if let percent = Double(percentString) {
                                DispatchQueue.main.async {
                                    withAnimation(.linear(duration: 0.12)) {
                                        item.progress = percent / 100.0
                                    }
                                }
                        }
                    }
                }
            }
            
            // Detect processing phase
            if line.contains("[ExtractAudio]") || line.contains("[ffmpeg]") {
                DispatchQueue.main.async {
                    withAnimation(.easeIn(duration: 0.18)) {
                        item.status = .processing
                    }
                    self.statusMessage = "Processing: \(item.title)"
                }
            }
        }
    }
}
